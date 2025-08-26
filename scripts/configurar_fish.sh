#!/bin/bash
echo "Detectando gerenciador de pacotes para instalar starship, eza, zoxide e fish..."

# Detectar gerenciador de pacotes
detect_package_manager() {
  for pm in pacman apt dnf zypper; do
    if command -v $pm &>/dev/null; then
      echo "$pm"
      return
    fi
  done
  echo "unknown"
}

# Instalar pacotes conforme o gerenciador detectado
install_packages() {
  case $1 in
    pacman)
      echo "Instalando starship, eza, zoxide e fish via pacman..."
      pacman -Sy --noconfirm --needed starship eza zoxide fish
      ;;
    apt)
      echo "Instalando starship, eza, zoxide e fish via apt..."
      apt update
      apt install -y gpg wget
      mkdir -p /etc/apt/keyrings
      wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
      echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" > /etc/apt/sources.list.d/gierens.list
      chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
      apt update
      apt install -y --no-install-recommends starship eza zoxide fish
      ;;
    dnf)
      echo "Instalando starship, eza, zoxide e fish via dnf..."
      dnf install -y starship eza zoxide fish
      ;;
    zypper)
      echo "Instalando starship, eza, zoxide e fish via zypper..."
      zypper --non-interactive install -y starship eza zoxide fish
      ;;
    *)
      echo "Gerenciador de pacotes desconhecido. Instale os pacotes manualmente."
      ;;
  esac
}

# Detectar usuário real que executou sudo
REAL_USER=$(logname 2>/dev/null || echo "$SUDO_USER" || echo "$USER")
REAL_HOME=$(eval echo "~$REAL_USER")

# Rodar instalação
PM=$(detect_package_manager)
install_packages "$PM"

# Configurar Fish como shell padrão para o usuário real
echo "Configurando fish como shell padrão para $REAL_USER..."
chsh -s /usr/bin/fish "$REAL_USER"

#echo "Instalando Oh My Fish (OMF)..."
#curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish

#echo "Instalando tema lambda no OMF..."
#fish -c "omf install lambda"

# Configuração do Fish
echo "Configurando arquivo de configuração do fish..."

CONFIG_DIR="$REAL_HOME/.config/fish"
CONFIG_FILE="$CONFIG_DIR/config.fish"

mkdir -p "$CONFIG_DIR"
touch "$CONFIG_FILE"

add_config_line() {
  local line="$1"
  grep -qxF "$line" "$CONFIG_FILE" || echo "$line" >> "$CONFIG_FILE"
}

add_config_line 'set -g fish_greeting ""'
add_config_line 'alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"'
add_config_line 'zoxide init fish | source'

# Garantir que o usuário real tenha permissão total na pasta
chown -R "$REAL_USER":"$REAL_USER" "$CONFIG_DIR"

echo "✅ Configuração do Fish concluída! Faça logout/login para ativar o Fish como shell padrão."

