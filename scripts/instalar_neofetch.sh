#!/bin/bash
echo "[INFO] Detectando gerenciador de pacotes..."

# Detecta gerenciador de pacotes
detect_pm() {
  for pm in apt pacman dnf zypper; do
    if command -v "$pm" &>/dev/null; then
      echo "$pm"
      return
    fi
  done
  echo "unsupported"
}

# Instala Neofetch
install_neofetch() {
  case "$1" in
    apt)
      echo "[INFO] Instalando Neofetch via apt..."
      apt update
      apt install -y neofetch
      ;;
    pacman)
      echo "[INFO] Instalando Neofetch via pacman..."
      pacman -Sy --noconfirm neofetch
      ;;
    dnf)
      echo "[INFO] Instalando Neofetch via dnf..."
      dnf install -y neofetch
      ;;
    zypper)
      echo "[INFO] Instalando Neofetch via zypper..."
      zypper install -y neofetch
      ;;
    *)
      echo "[ERRO] Gerenciador de pacotes não suportado. Instale Neofetch manualmente."
      exit 1
      ;;
  esac
}

# Adiciona Neofetch a um arquivo de configuração
add_neofetch() {
  local rc_file="$1"
  local shell_name="$2"

  echo "[INFO] Configurando Neofetch para $shell_name em $rc_file..."

  # Garante que o diretório e o arquivo existam
  mkdir -p "$(dirname "$rc_file")"
  if ! touch "$rc_file" 2>/dev/null; then
    echo "[ERRO] Não foi possível criar ou acessar $rc_file. Verifique as permissões."
    return 1
  fi

  # Define permissões corretas para o usuário nandex
  chown nandex:nandex "$rc_file"
  chmod 644 "$rc_file"

  # Remove linhas antigas de neofetch
  if [ -f "$rc_file" ]; then
    sed -i '/neofetch/d' "$rc_file"
  fi

  if [ "$shell_name" = "fish" ]; then
    echo "[INFO] Processando Fish shell..."
    tmp_file=$(mktemp)
    inside_block=0
    added=0

    # Se o arquivo está vazio, cria um novo bloco interativo
    if [ ! -s "$rc_file" ]; then
      echo "[INFO] Arquivo $rc_file está vazio. Criando novo bloco interativo."
      echo -e "if status is-interactive\n    neofetch\nend" > "$tmp_file"
      added=1
    else
      # Lê o arquivo linha por linha
      while IFS= read -r line || [ -n "$line" ]; do
        # Adiciona neofetch antes do 'end' do bloco interativo
        if echo "$line" | grep -E '^[[:space:]]*end[[:space:]]*$' >/dev/null && [ $inside_block -eq 1 ] && [ $added -eq 0 ]; then
          echo "[DEBUG] Adicionando neofetch antes do 'end'."
          echo "    neofetch" >> "$tmp_file"
          added=1
        fi
        # Escreve a linha atual no arquivo temporário
        echo "$line" >> "$tmp_file"
        # Verifica se a linha contém o início do bloco interativo
        if echo "$line" | grep -E '^[[:space:]]*if[[:space:]]+status[[:space:]]+is-interactive' >/dev/null; then
          echo "[DEBUG] Bloco interativo encontrado: $line"
          inside_block=1
        fi
      done < "$rc_file"

      # Se nenhum bloco interativo foi encontrado, adiciona um novo
      if [ $added -eq 0 ]; then
        echo "[INFO] Nenhum bloco interativo encontrado. Adicionando novo bloco."
        echo -e "\nif status is-interactive\n    neofetch\nend" >> "$tmp_file"
      fi
    fi

    # Exibe o conteúdo do arquivo temporário para depuração
    echo "[DEBUG] Conteúdo do arquivo temporário ($tmp_file):"
    cat "$tmp_file"

    # Substitui o arquivo original
    if mv "$tmp_file" "$rc_file" 2>/dev/null; then
      # Define permissões corretas após a substituição
      chown nandex:nandex "$rc_file"
      chmod 644 "$rc_file"
      echo "[OK] Neofetch adicionado com sucesso em $rc_file"
    else
      echo "[ERRO] Falha ao substituir $rc_file. Verifique as permissões."
      return 1
    fi
  else
    echo -e "\n# Inicia Neofetch automaticamente\nneofetch" >> "$rc_file"
    # Define permissões corretas
    chown nandex:nandex "$rc_file"
    chmod 644 "$rc_file"
    echo "[OK] Neofetch adicionado com sucesso em $rc_file"
  fi
}

# Configura Neofetch para todos os shells instalados
setup_neofetch_for_installed_shells() {
  for sh in bash zsh fish; do
    if command -v "$sh" &>/dev/null; then
      echo "[INFO] Shell $sh detectado."
      case "$sh" in
        bash)
          add_neofetch "/home/nandex/.bashrc" "bash"
          ;;
        zsh)
          add_neofetch "/home/nandex/.zshrc" "zsh"
          ;;
        fish)
          add_neofetch "/home/nandex/.config/fish/config.fish" "fish"
          ;;
      esac
    else
      echo "[INFO] Shell $sh não encontrado. Pulando configuração."
    fi
  done
}

# Instala Neofetch se não existir
if ! command -v neofetch &>/dev/null; then
  PM=$(detect_pm)
  install_neofetch "$PM"
else
  echo "[INFO] Neofetch já está instalado."
fi

# Verifica se o neofetch está acessível
if command -v neofetch &>/dev/null; then
  echo "[INFO] Neofetch encontrado em: $(command -v neofetch)"
else
  echo "[ERRO] Neofetch não encontrado no PATH. Verifique a instalação."
  exit 1
fi

# Configura o arquivo de configuração do Neofetch
echo "[INFO] Configurando arquivo de configuração do Neofetch..."
mkdir -p /home/nandex/.config/neofetch
cat > /home/nandex/.config/neofetch/config.conf << 'EOF'
# Source: https://github.com/Chick2D/neofetch-themes/
# Made by https://github.com/tralph3 
# Customization Wiki https://github.com/dylanaraps/neofetch/wiki/Customizing-Info

# Colour config is here and in .zshrc

print_info() {
    info title
    info underline

    prin "$(color 12)╭──────────── $(color 10)Software$(color 12) ────────────"
    info "$(color 12)│ $(color 14)OS" distro
    info "$(color 12)│ $(color 14)Kernel" kernel
    info "$(color 12)│ $(color 14)Packages" packages
    info "$(color 12)│ $(color 14)Shell" shell
    info "$(color 12)│ $(color 14)DE" de
    info "$(color 12)│ $(color 14)Terminal" term
    info "$(color 12)│ $(color 14)Local IP" local_ip
    prin "$(color 12)├──────────── $(color 10)Hardware$(color 12) ────────────"
    info "$(color 12)│ $(color 14)Host" model
    info "$(color 12)│ $(color 14)CPU" cpu
    info "$(color 12)│ $(color 14)GPU" gpu
    info "$(color 12)│ $(color 14)Memory" memory
    info "$(color 12)│ $(color 14)Disk" disk
    prin "$(color 12)├───────────── $(color 10)Uptime$(color 12) ─────────────"
    info "$(color 12)│" uptime
    prin "$(color 12)╰──────────────────────────────────"

    info cols
}

title_fqdn="off"
kernel_shorthand="on"
distro_shorthand="on"
os_arch="off"
uptime_shorthand="off"
memory_percent="off"
memory_unit="mib"
package_managers="on"
shell_path="off"
shell_version="on"
cpu_brand="on"
cpu_speed="on"
cpu_cores="logical"
cpu_temp="off"
gpu_type="all"
refresh_rate="on"
gtk_shorthand="on"
gtk2="on"
gtk3="on"
public_ip_host="http://ident.me"
public_ip_timeout=2
de_version="on"
disk_subtitle="dir"
disk_percent="on"
music_player="auto"
song_format="%artist% - %title%"
mpc_args=()
colors=(distro)
underline_enabled="on"
underline_char="¨"
separator="›"
color_blocks="on"
block_width=3
block_height=1
col_offset="auto"
bar_char_elapsed="-"
bar_char_total="="
bar_border="on"
bar_length=15
bar_color_elapsed="distro"
bar_color_total="distro"
cpu_display="off"
memory_display="off"
battery_display="off"
disk_display="off"
image_source="auto"
ascii_distro="auto"
ascii_bold="on"
image_loop="off"
thumbnail_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/thumbnails/neofetch"
crop_mode="normal"
crop_offset="center"
image_size="auto"
gap=3
yoffset=0
xoffset=0
background_color=
stdout="off"
EOF

# Define permissões corretas para o arquivo de configuração do Neofetch
chown nandex:nandex /home/nandex/.config/neofetch/config.conf
chmod 644 /home/nandex/.config/neofetch/config.conf

# Configura Neofetch nos shells instalados
setup_neofetch_for_installed_shells

echo "[FINALIZADO] Abra um novo terminal como o usuário nandex para ver o Neofetch em ação."
