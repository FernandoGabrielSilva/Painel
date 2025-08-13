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

install_fastfetch() {
  case "$1" in
    apt)
      echo "Instalando Fastfetch via apt..."
      sudo apt update
      sudo apt install -y fastfetch
      ;;
    pacman)
      echo "Instalando Fastfetch via pacman..."
      sudo pacman -Sy --noconfirm fastfetch
      ;;
    dnf)
      echo "Instalando Fastfetch via dnf..."
      sudo dnf install -y fastfetch
      ;;
    zypper)
      echo "Instalando Fastfetch via zypper..."
      sudo zypper install -y fastfetch
      ;;
    *)
      echo "Gerenciador de pacotes não suportado. Instale Fastfetch manualmente."
      exit 1
      ;;
  esac
}

if ! command -v fastfetch &>/dev/null; then
  PM=$(detect_pm)
  install_fastfetch "$PM"
else
  echo "Fastfetch já está instalado."
fi

