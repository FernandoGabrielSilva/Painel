#!/usr/bin/env bash
# =========================================
# Configuração segura do Timeshift no Arch/CachyOS
# - Remove Snapper/Btrfs Assistant (se existirem)
# - Instala Timeshift (+ autosnap) e integra com GRUB (grub-btrfs)
# - Detecção de bootloader (grub/systemd-boot/outros)
# - Pré-snapshot Btrfs + rollback automático em caso de falha
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
  command -v "$1" >/dev/null 2>&1 || {
    err "Comando '$1' não encontrado."
    return 1
  }
}

### ===== Segurança básica =====
if [[ $EUID -ne 0 ]]; then
  err "Execute como root. Use: sudo $0"
  exit 1
fi
ok "Permissões de root confirmadas."

### ===== Verificações de ambiente =====
info "Verificando conectividade de rede..."
if ! ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
  warn "Sem resposta de archlinux.org, tentando 1.1.1.1..."
  if ! ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then
    err "Sem conectividade com a Internet. Verifique a rede e tente novamente."
    exit 1
  fi
fi
ok "Conectividade OK."

info "Verificando lock do pacman..."
if [[ -e /var/lib/pacman/db.lck ]]; then
  err "Pacman está bloqueado (/var/lib/pacman/db.lck). Feche outras operações e remova o lock com cautela."
  exit 1
fi
ok "Sem lock do pacman."

### ===== Detectar helper AUR (fallback) =====
AUR_HELPER=""
if command -v yay >/dev/null 2>&1; then AUR_HELPER="yay"; fi
if [[ -z "$AUR_HELPER" ]] && command -v paru >/dev/null 2>&1; then AUR_HELPER="paru"; fi

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
  warn "Raiz não é Btrfs (FSTYPE=$FSTYPE). Timeshift funciona, mas snapshots de sistema não serão Btrfs."
fi

### ===== Snapshot/rollback =====
SNAP_CREATED=0
SNAP_TYPE=""           # "snapper" ou "btrfs"
SNAP_ID=""             # id do snapper OU nome do subvolume de snapshot
SNAP_PATH=""           # caminho do snapshot btrfs
SNAP_DESC="pre-config-timeshift-$(date +%Y%m%d-%H%M%S)"

create_pre_snapshot() {
  if [[ "$IS_BTRFS" -ne 1 ]]; then
    warn "Sem Btrfs: pulando pré-snapshot de sistema."
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

  # Fallback: snapshot direto via btrfs (somente do subvolume raiz)
  need_cmd btrfs || { warn "btrfs-progs ausente; pulando pré-snapshot."; return 0; }

  # Tentar descobrir subvolume raiz (@ ou similar)
  ROOT_SUBVOL=$(btrfs subvolume show / 2>/dev/null | awk -F': ' '/Name:/ {print $2; exit}' || echo "/")
  [[ -z "$ROOT_SUBVOL" ]] && ROOT_SUBVOL="@"
  SNAP_DIR="/.snapshots"
  SNAP_NAME="${SNAP_DESC}"
  SNAP_PATH="${SNAP_DIR}/${SNAP_NAME}"

  info "Criando diretório de snapshots em $SNAP_DIR (se necessário)..."
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
  # Chamado via trap ERR
  local ec=$?
  if [[ $ec -eq 0 ]]; then return 0; fi
  err "Falha detectada (exit code $ec). Iniciando rotina de rollback..."

  if [[ "$SNAP_CREATED" -eq 1 && "$IS_BTRFS" -eq 1 ]]; then
    if [[ "$SNAP_TYPE" == "snapper" && "$SNAP_ID" != "" && "$SNAP_ID" != "DRY_RUN" ]]; then
      warn "Rollback: será criado um snapshot de restauração e definido como default (método seguro)."
      # Estratégia segura: criar snapshot de restore e sugerir reboot via GRUB-BTRFS
      if command -v snapper >/dev/null 2>&1; then
        info "Criando snapshot de recuperação (snapper)..."
        snapper -c root create -d "rollback-from-error-$(date +%Y%m%d-%H%M%S)"
      fi
      warn "Se possuir grub-btrfs, gere o menu e reinicie para restaurar:"
      echo "  grub-mkconfig -o /boot/grub/grub.cfg"
      echo "  Reboot -> selecione o snapshot correspondente."
    elif [[ "$SNAP_TYPE" == "btrfs" && -n "$SNAP_PATH" && "$SNAP_PATH" != "DRY_RUN" ]]; then
      warn "Rollback (btrfs): será restaurado o subvolume raiz a partir de $SNAP_PATH."
      if [[ "${DRY_RUN:-0}" == "1" ]]; then
        echo "DRY_RUN> mount --bind / /mnt"
        echo "DRY_RUN> btrfs subvolume snapshot \"$SNAP_PATH\" /mnt/@restore-$(date +%s)"
        echo "DRY_RUN> # Você pode definir o subvolume default e reiniciar."
      else
        # Modo não-destrutivo: criar subvolume restaurado e instruir o usuário
        mount --bind / /mnt
        RESTORE_NAME="@restore-$(date +%s)"
        btrfs subvolume snapshot "$SNAP_PATH" "/mnt/$RESTORE_NAME"
        umount /mnt || true
        warn "Snapshot restaurado em /$RESTORE_NAME."
        warn "Para aplicar totalmente (com cuidado!):"
        echo "  btrfs subvolume set-default \"$(btrfs subvolume list / | awk -v n=\"$RESTORE_NAME\" '$0 ~ n {print $9; exit}')\" /"
        echo "  reboot"
      fi
    fi
  else
    warn "Nenhum pré-snapshot disponível para rollback de sistema."
    warn "Tentando reverter alterações de pacotes (melhor-esforço)..."
    # Reinstalar o que foi removido, remover o que foi instalado
    if pacman -Qi snapper >/dev/null 2>&1; then
      :
    else
      info "Reinstalando snapper e btrfs-assistant (se possível)..."
      run "pacman -S --noconfirm snapper btrfs-assistant || true"
    fi
  fi

  err "Saindo com erro. Veja o log em $LOG_FILE."
  exit "$ec"
}

trap rollback_on_error ERR

### ===== Início da execução =====
info "Iniciando rotina segura (log em $LOG_FILE). DRY_RUN=${DRY_RUN:-0}"

# Pré-snapshot (se possível)
create_pre_snapshot

### ===== Remover Snapper e Btrfs-assistant =====
info "Removendo snapper e btrfs-assistant (se instalados)..."
run "pacman -Rns --noconfirm snapper btrfs-assistant || true"
ok "Etapa de remoção concluída."

### ===== Instalar Timeshift =====
info "Instalando Timeshift..."
# Preferir repositório oficial
if pacman -Si timeshift >/dev/null 2>&1; then
  run "pacman -S --noconfirm timeshift"
  ok "Timeshift instalado dos repositórios oficiais."
else
  if [[ -n "$AUR_HELPER" ]]; then
    info "Timeshift não encontrado nos repositórios. Tentando via AUR com $AUR_HELPER..."
    run "$AUR_HELPER -S --noconfirm timeshift"
    ok "Timeshift instalado via AUR."
  else
    err "Timeshift não encontrado e nenhum helper AUR disponível."
    exit 1
  fi
fi

### ===== Ativar cronie =====
info "Ativando e iniciando cronie..."
run "systemctl enable cronie --now"
ok "cronie ativo."

### ===== Integrar com GRUB (se GRUB) =====
if [[ "$BOOTLOADER" == "grub" ]]; then
  info "Instalando grub-btrfs e inotify-tools..."
  run "pacman -S --noconfirm grub-btrfs inotify-tools"

  info "Habilitando grub-btrfsd..."
  run "systemctl enable --now grub-btrfsd"

  info "Regenerando configuração do GRUB..."
  if [[ -x /usr/bin/grub-mkconfig ]]; then
    run "grub-mkconfig -o /boot/grub/grub.cfg"
    ok "Configuração do GRUB regenerada."
  else
    warn "grub-mkconfig não encontrado; pulei regeneração automática."
  fi

  info "Status do grub-btrfsd (resumo):"
  run "systemctl --no-pager --full status grub-btrfsd || true"
else
  warn "Bootloader não é GRUB: pulando instalação de grub-btrfs."
  if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    info "Dica: em systemd-boot, use timeshift + timeshift-autosnap, mas entrará manualmente se precisar restaurar."
  fi
fi

### ===== Instalar timeshift-autosnap =====
info "Instalando timeshift-autosnap..."
# Em algumas distros está em repositório; em outras, na AUR
if pacman -Si timeshift-autosnap >/dev/null 2>&1; then
  run "pacman -S --noconfirm timeshift-autosnap"
else
  if [[ -n "$AUR_HELPER" ]]; then
    run "$AUR_HELPER -S --noconfirm timeshift-autosnap"
  else
    warn "timeshift-autosnap não está nos repositórios e não há AUR helper; pulando."
  fi
fi
ok "timeshift-autosnap: etapa concluída (instalado ou ignorado)."

### ===== Validações pós-instalação =====
info "Validando instalações..."
need_cmd timeshift && ok "Timeshift disponível."
systemctl is-enabled cronie >/dev/null 2>&1 && ok "cronie habilitado."
systemctl is-active cronie >/dev/null 2>&1 && ok "cronie ativo."

if [[ "$BOOTLOADER" == "grub" ]]; then
  pacman -Qi grub-btrfs >/dev/null 2>&1 && ok "grub-btrfs instalado."
  systemctl is-active grub-btrfsd >/dev/null 2>&1 && ok "grub-btrfsd ativo."
fi

### ===== Sucesso =====
ok "Configuração concluída com sucesso! 🚀"

if [[ "$IS_BTRFS" -eq 1 && "$SNAP_CREATED" -eq 1 ]]; then
  info "Mantendo o pré-snapshot criado para segurança:"
  if [[ "$SNAP_TYPE" == "snapper" ]]; then
    echo "  snapper -c root list | grep \"$SNAP_DESC\"   # para consultar"
  else
    echo "  ls -l \"$SNAP_PATH\"                         # para consultar"
  fi
  info "Se tudo estiver ok após alguns dias, você pode remover esse snapshot para liberar espaço."
fi

echo
info "Log completo em: $LOG_FILE"
echo

