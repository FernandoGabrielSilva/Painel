#!/bin/bash

echo "Instalando dependências base para compilar pacotes AUR..."
sudo pacman -S --needed git base-devel --noconfirm

echo "Clonando repositório do yay na pasta /tmp..."
cd /tmp || exit 1

if [ -d "yay" ]; then
    echo "Diretório /tmp/yay já existe. Removendo..."
    rm -rf yay
fi

git clone https://aur.archlinux.org/yay.git || { echo "Erro ao clonar yay."; exit 1; }

# Muda a propriedade da pasta para o usuário comum
chown -R "$SUDO_USER":"$SUDO_USER" /tmp/yay

echo "Compilando yay como usuário normal..."
sudo -u "$SUDO_USER" bash -c '
    cd /tmp/yay || exit 1
    makepkg -s --noconfirm || { echo "Erro ao compilar yay."; exit 1; }
'

# Pega o caminho do pacote gerado
PKG_FILE=$(find /tmp/yay -name "*.pkg.tar.zst" | head -n 1)

if [ -f "$PKG_FILE" ]; then
    echo "Instalando yay como root com pacman -U..."
    sudo pacman -U --noconfirm "$PKG_FILE" || { echo "❌ Falha ao instalar o pacote yay."; exit 1; }
    echo "✅ yay instalado com sucesso!"
else
    echo "❌ Pacote .pkg.tar.zst não encontrado. Instalação abortada."
    exit 1
fi

