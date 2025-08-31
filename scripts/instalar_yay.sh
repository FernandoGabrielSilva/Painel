#!/usr/bin/env bash
PASSWORD="$1"
set -e

# Função para rodar sudo com senha direto
run_sudo() {
  printf "%s\n" "$PASSWORD" | sudo -S "$@"
}

echo "[INFO] Validando permissões de superusuário..."
printf "%s\n" "$PASSWORD" | sudo -S -v

echo "[INFO] Removendo lock do pacman (se existir)..."
run_sudo rm -f /var/lib/pacman/db.lck

echo "[INFO] Instalando dependências necessárias..."
run_sudo pacman -Syu --needed --noconfirm git base-devel

YAY_DIR="/tmp/yay"

if [ -d "$YAY_DIR" ]; then
    echo "[INFO] Diretório $YAY_DIR já existe, atualizando repositório..."
    cd "$YAY_DIR"
    git pull
else
    echo "[INFO] Clonando repositório do Yay..."
    git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
    cd "$YAY_DIR"
fi

echo "[INFO] Compilando Yay..."
makepkg -s --noconfirm

echo "[INFO] Instalando Yay..."
run_sudo pacman -U --noconfirm *.pkg.tar.zst

echo "[INFO] Yay instalado com sucesso!"

