#!/bin/bash
echo "Instalando dependências base para compilar pacotes AUR..."

sudo pacman -S --needed git base-devel --noconfirm

echo "Clonando repositório do yay na pasta /tmp..."
cd /tmp || exit

git clone https://aur.archlinux.org/yay.git

echo "Compilando e instalando yay..."
cd yay || exit
makepkg -si --noconfirm

echo "✅ yay instalado com sucesso!"

