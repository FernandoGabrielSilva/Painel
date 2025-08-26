#!/bin/bash

echo "🔍 Detectando gerenciador de pacotes..."

detect_pm() {
  for pm in apt pacman dnf zypper; do
    if command -v "$pm" &>/dev/null; then
      echo "$pm"
      return
    fi
  done
  echo "unsupported"
}

install_wine() {
  case "$1" in
    apt)
      echo "📦 Instalando Wine via apt..."
      sudo apt update
      sudo apt install -y wine
      ;;
    pacman)
      echo "📦 Instalando Wine via pacman..."
      sudo pacman -Sy --noconfirm wine
      ;;
    dnf)
      echo "📦 Instalando Wine via dnf..."
      sudo dnf install -y wine
      ;;
    zypper)
      echo "📦 Instalando Wine via zypper..."
      sudo zypper install -y wine
      ;;
    *)
      echo "❌ Gerenciador de pacotes não suportado. Instale o Wine manualmente."
      exit 1
      ;;
  esac
}

# Verifica se Wine já está instalado
if ! command -v wine &>/dev/null; then
  PM=$(detect_pm)
  install_wine "$PM"
else
  echo "✅ Wine já está instalado."
fi

# Executa winecfg
echo "⚙️ Executando winecfg para configuração inicial..."
winecfg

# Cria o atalho .desktop no diretório do usuário correto
USER_HOME=$(eval echo "~${SUDO_USER:-$USER}")
DESKTOP_DIR="$USER_HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/wine-exe.desktop"

mkdir -p "$DESKTOP_DIR"

tee "$DESKTOP_FILE" > /dev/null <<EOF
[Desktop Entry]
Name=Wine
Exec=wine start /unix %f
Type=Application
MimeType=application/x-ms-dos-executable
Terminal=false
Icon=wine
EOF

chmod +x "$DESKTOP_FILE"
echo "✅ Arquivo $DESKTOP_FILE criado com sucesso!"

# Associa arquivos .exe ao Wine
echo "🔗 Associando arquivos .exe ao Wine..."
if command -v xdg-mime &>/dev/null; then
  xdg-mime default wine-exe.desktop application/x-ms-dos-executable
  echo "✅ Arquivos .exe associados ao Wine com sucesso!"
else
  echo "❌ Comando xdg-mime não encontrado. A associação não foi feita."
fi

echo "🎉 Wine instalado, configurado e arquivos .exe associados com sucesso!"

