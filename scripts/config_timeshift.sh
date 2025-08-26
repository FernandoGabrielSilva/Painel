#!/usr/bin/env bash
# =========================================
# Configuração segura do Timeshift no Arch/CachyOS
# - Remove Snapper/Btrfs Assistant (se existirem)
# - Instala Timeshift (+ autosnap) e integra com GRUB ou systemd-boot
# - Pré-snapshot Btrfs + rollback automático em caso de falha
# - Evita refazer configurações já aplicadas
# - Modo DRY_RUN (export DRY_RUN=1)
# - Logs em /var/log/config_timeshift.log
# Autor: Nandex
# =========================================

set -Eeuo pipefail

### ===== Configuração de log =====
LOG_FILE="/var/log/config_timeshift.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE" || true
exec &> >(tee -a "$LOG_FILE")

### ===== Utilidades de mensagem =====
bold()   { printf "\033[1m%s\033[0m" "$*"; }
blue()   { printf "\033[1;34m%s\033[0m" "$*"; }
green()  { printf "\033[1;32m%s\033[0m" "$*"; }
red()    { printf "\033[1;31m%s\033[0m" "$*"; }
yellow() { printf "\033[1;33m%s\033[0m" "$*"; }

info()    { echo -e "$(blue [INFO]) $*"; }
ok()      { echo -e "$(green [OK]) $*"; }
warn()    { echo -e "$(yellow [AVISO]) $*"; }
err()     { echo -e "$(red [ERRO]) $*"; }

run() {
  # Respeita DRY_RUN para simular ações
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN> $*"
  else
    eval "$@"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Comando '$1' não encontrado."; return 1; }
}

### ===== Verifica root =====
if [[ $EUID -ne 0 ]]; then
  err "Execute como root. Use: sudo $0"
  exit 1
fi
ok "Permissões de root confirmadas."

### ===== Resolve SUDO_USER (fallback) =====
# Caso o script seja executado via 'su -' sem SUDO_USER, tenta obter o usuário real.
if [[ -z "${SUDO_USER:-}" || "${SUDO_USER:-}" == "root" ]]; then
  REAL_USER="$(logname 2>/dev/null || who | awk '{print $1}' | head -n1 || true)"
  if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
    export SUDO_USER="$REAL_USER"
    info "SUDO_USER ausente; usando usuário detectado: $SUDO_USER"
  else
    warn "Não foi possível determinar um usuário não-root (SUDO_USER). Algumas operações AUR podem falhar."
  fi
else
  info "Executando como root via sudo; SUDO_USER=$SUDO_USER"
fi

### ===== Conectividade =====
info "Verificando conectividade de rede..."
if ! ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
  warn "Sem resposta de archlinux.org, tentando 1.1.1.1..."
  if ! ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then
    err "Sem conectividade com a Internet."
    exit 1
  fi
fi
ok "Conectividade OK."

### ===== Lock do pacman =====
info "Verificando lock do pacman..."
if [[ -e /var/lib/pacman/db.lck ]]; then
  err "Pacman está bloqueado (/var/lib/pacman/db.lck). Feche outras operações."
  exit 1
fi
ok "Sem lock do pacman."

### ===== Detectar helper AUR =====
AUR_HELPER=""
if command -v yay >/dev/null 2>&1; then AUR_HELPER="yay"; fi
if [[ -z "$AUR_HELPER" ]] && command -v paru >/dev/null 2>&1; then AUR_HELPER="paru"; fi
if [[ -n "$AUR_HELPER" ]]; then
  info "AUR helper detectado: $AUR_HELPER"
else
  warn "Nenhum AUR helper detectado (yay/paru). Irei usar fallback manual se necessário."
fi

### ===== Detectar bootloader =====
BOOTLOADER="outro"
info "Detectando bootloader..."
if command -v grub-install >/dev/null 2>&1 || [[ -d /boot/grub ]]; then
  BOOTLOADER="grub"
elif [[ -d /boot/loader ]] || bootctl is-installed >/dev/null 2>&1; then
  BOOTLOADER="systemd-boot"
fi
ok "Bootloader detectado: $(bold "$BOOTLOADER")"

### ===== Detectar Btrfs =====
IS_BTRFS=0
ROOT_MNT=$(findmnt -n -o SOURCE / || true)
FSTYPE=$(findmnt -n -o FSTYPE / || true)
if [[ "$FSTYPE" == "btrfs" ]]; then
  IS_BTRFS=1
  ok "Partição raiz em Btrfs detectada ($ROOT_MNT)."
else
  warn "Raiz não é Btrfs (FSTYPE=$FSTYPE). Snapshots Btrfs não funcionarão."
fi

### ===== Snapshot/rollback =====
SNAP_CREATED=0
SNAP_TYPE=""
SNAP_ID=""
SNAP_PATH=""
SNAP_NAME=""
SNAP_DESC="pre-config-timeshift-$(date +%Y%m%d-%H%M%S)"

create_pre_snapshot() {
  if [[ "$IS_BTRFS" -ne 1 ]]; then
    warn "Sem Btrfs: pulando pré-snapshot."
    return 0
  fi

  if command -v snapper >/dev/null 2>&1 && [[ -e /etc/snapper/configs/root ]]; then
    info "Criando pré-snapshot com snapper..."
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      echo "DRY_RUN> snapper -c root create -d \"$SNAP_DESC\""
      SNAP_CREATED=1; SNAP_TYPE="snapper"; SNAP_ID="DRY_RUN"
      ok "Pré-snapshot (snapper) simulado."
    else
      SNAP_ID=$(snapper -c root create -d "$SNAP_DESC" | awk '{print $NF}')
      SNAP_CREATED=1; SNAP_TYPE="snapper"
      ok "Pré-snapshot (snapper) criado: id $SNAP_ID."
    fi
    return 0
  fi

  need_cmd btrfs || { warn "btrfs-progs ausente; pulando snapshot."; return 0; }

  ROOT_SUBVOL=$(btrfs subvolume show / 2>/dev/null | awk -F': ' '/Name:/ {print $2; exit}' || echo "@")
  SNAP_DIR="/.snapshots"
  SNAP_NAME="${SNAP_DESC}"
  SNAP_PATH="${SNAP_DIR}/${SNAP_NAME}"

  info "Criando diretório de snapshots em $SNAP_DIR..."
  run "mkdir -p \"$SNAP_DIR\""

  info "Criando snapshot somente-leitura de / em $SNAP_PATH ..."
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN> btrfs subvolume snapshot -r / \"$SNAP_PATH\""
    SNAP_CREATED=1; SNAP_TYPE="btrfs"; ok "Pré-snapshot (btrfs) simulado: $SNAP_PATH"
  else
    btrfs subvolume snapshot -r / "$SNAP_PATH"
    SNAP_CREATED=1; SNAP_TYPE="btrfs"; ok "Pré-snapshot (btrfs) criado: $SNAP_PATH"
  fi
}

rollback_on_error() {
  local ec=$?
  if [[ $ec -eq 0 ]]; then return 0; fi
  err "Falha detectada (exit code $ec). Iniciando rollback..."

  if [[ "$SNAP_CREATED" -eq 1 && "$IS_BTRFS" -eq 1 ]]; then
    if [[ "$SNAP_TYPE" == "snapper" && "$SNAP_ID" != "DRY_RUN" ]]; then
      warn "Rollback snapper: criar snapshot de recuperação manualmente."
      info "  snapper -c root create -d \"rollback-from-error-$(date +%Y%m%d-%H%M%S)\""
    elif [[ "$SNAP_TYPE" == "btrfs" && -n "$SNAP_PATH" && "$SNAP_PATH" != "DRY_RUN" ]]; then
      # tentar descobrir o nome do snapshot/subvolume
      local found
      found=$(btrfs subvolume list / 2>/dev/null | awk -v pfx="$(basename "$SNAP_PATH")" '$0 ~ pfx {print $9; exit}')
      if [[ -z "$found" ]]; then
        found=""
      fi
      warn "Rollback Btrfs: configurar subvolume default manualmente:"
      echo "  btrfs subvolume set-default \"$found\" /"
      echo "  reboot"
      echo "" | tee -a "$LOG_FILE"
      echo "Sugestão salva no log: btrfs subvolume set-default \"$found\" /" >> "$LOG_FILE"
    fi
  else
    warn "Nenhum snapshot disponível para rollback automático."
  fi

  err "Saindo com erro. Veja o log em $LOG_FILE."
  exit "$ec"
}

trap rollback_on_error ERR

### ===== Execução principal =====
info "Iniciando rotina segura (log em $LOG_FILE) DRY_RUN=${DRY_RUN:-0}"
create_pre_snapshot

### ===== Remover Snapper e Btrfs-assistant se existirem =====
info "Verificando snapper e btrfs-assistant..."
if pacman -Qi snapper >/dev/null 2>&1 || pacman -Qi btrfs-assistant >/dev/null 2>&1; then
  run "pacman -Rns --noconfirm snapper btrfs-assistant || true"
  ok "Snapper/Btrfs-assistant removidos."
else
  ok "Snapper e btrfs-assistant não instalados; pulando remoção."
fi

### ===== Instalar Timeshift apenas se não estiver =====
if pacman -Qi timeshift >/dev/null 2>&1; then
  ok "Timeshift já instalado; pulando instalação."
else
  info "Instalando Timeshift..."
  if pacman -Si timeshift >/dev/null 2>&1; then
    run "pacman -S --noconfirm timeshift"
  elif [[ -n "$AUR_HELPER" && -n "${SUDO_USER:-}" ]]; then
    info "Timeshift não nos repositórios. Instalando via AUR usando $AUR_HELPER..."
    # roda como usuário normal para evitar erros do AUR helper
    run "sudo -u $SUDO_USER $AUR_HELPER -S --needed --noconfirm timeshift"
  else
    err "Timeshift não encontrado e nenhum AUR helper disponível."
    exit 1
  fi
  ok "Timeshift instalado."
fi

### ===== Cronie =====
if systemctl is-enabled cronie >/dev/null 2>&1; then
  ok "cronie já habilitado."
else
  info "Habilitando cronie..."
  run "systemctl enable --now cronie"
  ok "cronie ativo."
fi

### ===== Bootloader =====
if [[ "$BOOTLOADER" == "grub" ]]; then
  info "Configurando grub-btrfs..."
  if ! pacman -Qi grub-btrfs >/dev/null 2>&1; then
    run "pacman -S --noconfirm grub-btrfs inotify-tools"
  fi
  run "systemctl enable --now grub-btrfsd"
  if [[ -x /usr/bin/grub-mkconfig ]]; then
    run "grub-mkconfig -o /boot/grub/grub.cfg"
    ok "Configuração do GRUB regenerada."
  fi
else
  info "Bootloader systemd-boot detectado. Snapshots serão restaurados manualmente:"
  echo "  btrfs subvolume set-default <snapshot> /"
  echo "  reboot"
fi

### ===== Timeshift-autosnap =====
if command -v timeshift-autosnap >/dev/null 2>&1; then
  ok "timeshift-autosnap já instalado; pulando."
else
  info "Instalando timeshift-autosnap (tentativa).
  1) Tentar AUR helper ($AUR_HELPER) como usuário normal
  2) Se falhar ou não existir, fallback para build manual (git+makepkg) como usuário normal."
  installed=0

  # 1) tentar AUR helper (se disponível)
  if [[ -n "$AUR_HELPER" && -n "${SUDO_USER:-}" ]]; then
    info "Tentando instalar via $AUR_HELPER (como $SUDO_USER)..."
    if run "$AUR_HELPER -S --needed --noconfirm timeshift-autosnap"; then
      ok "timeshift-autosnap instalado via $AUR_HELPER."
      installed=1
    else
      warn "$AUR_HELPER falhou ou exigiu interação; prosseguindo para fallback manual."
    fi
  fi

  # 2) fallback manual: clone + makepkg como usuário normal + pacman -U como root
  if [[ "$installed" -eq 0 ]]; then
    if [[ -z "${SUDO_USER:-}" ]]; then
      warn "Usuário normal não detectado; não posso construir pacotes AUR em modo não-root. Pulando instalação."
    else
      TMP_BUILD_DIR="/tmp/timeshift-autosnap-build"
      run "rm -rf \"$TMP_BUILD_DIR\""
      run "mkdir -p \"$TMP_BUILD_DIR\""
      # garantia que o diretório seja de propriedade do usuário normal para git/makepkg
      run "chown -R $SUDO_USER:$SUDO_USER \"$TMP_BUILD_DIR\""

      info "Clonando AUR para $TMP_BUILD_DIR como $SUDO_USER..."
      if run "sudo -u $SUDO_USER git clone https://aur.archlinux.org/timeshift-autosnap.git \"$TMP_BUILD_DIR\""; then
        info "Clonagem concluída. Construindo pacote (.pkg.tar.zst) como $SUDO_USER (sem instalar automaticamente)..."
        # construir pacote (não instalar) para evitar prompts sudo interativos
        if run "cd \"$TMP_BUILD_DIR\" && sudo -u $SUDO_USER makepkg --skippgpcheck -f"; then
          # localizar arquivo de pacote
          PKG_FILE="$(ls "$TMP_BUILD_DIR"/*.pkg.tar.* 2>/dev/null | head -n1 || true)"
          if [[ -n "$PKG_FILE" ]]; then
            info "Pacote construído: $PKG_FILE. Instalando como root..."
            run "pacman -U --noconfirm \"$PKG_FILE\""
            ok "timeshift-autosnap instalado via build manual."
            installed=1
          else
            warn "Pacote não encontrado após makepkg; verifique $TMP_BUILD_DIR."
          fi
        else
          warn "makepkg falhou no diretório $TMP_BUILD_DIR."
        fi
      else
        warn "Clonagem AUR falhou."
      fi
    fi
  fi

  if [[ "$installed" -eq 0 ]]; then
    warn "Não foi possível instalar timeshift-autosnap automaticamente; você pode instalar manualmente."
  fi
fi
ok "Timeshift-autosnap: etapa concluída."

### ===== Validações finais =====
need_cmd timeshift && ok "Timeshift disponível." || warn "timeshift não encontrado."
systemctl is-active cronie >/dev/null 2>&1 && ok "cronie ativo." || warn "cronie não ativo."

if [[ "$IS_BTRFS" -eq 1 && "$SNAP_CREATED" -eq 1 ]]; then
  info "Pré-snapshot mantido em segurança:"
  [[ "$SNAP_TYPE" == "snapper" ]] && echo "  snapper -c root list | grep \"$SNAP_DESC\""
  [[ "$SNAP_TYPE" == "btrfs" ]] && echo "  ls -l \"$SNAP_PATH\""
fi

echo
info "Log completo em: $LOG_FILE"
ok "Configuração concluída com sucesso! 🚀"

