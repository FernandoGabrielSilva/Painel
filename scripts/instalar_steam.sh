#!/bin/bash
echo "Detectando gerenciador de pacotes..."

detect_pm() {
  for pm in apt pacman dnf zypper; do
    if command -v $pm &>/dev/null; then
      echo "$pm"
      return
    fi
  done
  echo "unsupported"
}

echo "Iniciando instalação do Steam..."

install_steam() {
  case "$1" in
    apt)
      echo "Instalando Steam via apt..."
      sudo apt update
      sudo apt install -y steam
      ;;
    pacman)
      echo "Instalando Steam via pacman..."
      sudo pacman -Sy --noconfirm steam
      ;;
    dnf)
      echo "Instalando Steam via dnf..."
      sudo dnf install -y steam
      ;;
    zypper)
      echo "Instalando Steam via zypper..."
      sudo zypper install -y steam
      ;;
    *)
      echo "Gerenciador de pacotes não suportado. Instale a Steam manualmente."
      exit 1
      ;;
  esac
}

PM=$(detect_pm)
install_steam "$PM"

echo "✅ Steam instalada!"

