#!/bin/bash
echo "Detectando gerenciador de pacotes para instalar starship, eza, zoxide e fish..."

detect_package_manager() {
  for pm in pacman apt dnf zypper; do
    if command -v $pm &>/dev/null; then
      echo "$pm"
      return
    fi
  done
  echo "unknown"
}

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

PM=$(detect_package_manager)
install_packages "$PM"

echo "Configurando fish como shell padrão..."
chsh -s /usr/bin/fish

#echo "Instalando Oh My Fish (OMF)..."
#curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish

#echo "Instalando tema lambda no OMF..."
#fish -c "omf install lambda"

echo "Configurando arquivo de configuração do fish..."

CONFIG_DIR="$HOME/.config/fish"
CONFIG_FILE="$CONFIG_DIR/config.fish"

mkdir -p "$CONFIG_DIR"

grep -q 'set -g fish_greeting' "$CONFIG_FILE" 2>/dev/null || echo 'set -g fish_greeting ""' >> "$CONFIG_FILE"
grep -q 'alias ls=' "$CONFIG_FILE" 2>/dev/null || echo 'alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"' >> "$CONFIG_FILE"
grep -q 'zoxide init fish' "$CONFIG_FILE" 2>/dev/null || echo 'zoxide init fish | source' >> "$CONFIG_FILE"

echo "✅ Configuração do Fish concluída!"

