#!/bin/bash
echo "Detectando GPU para instalar drivers corretos..."

GPU=$(lspci | grep VGA)

if echo "$GPU" | grep -qi "nvidia"; then
  echo "GPU NVIDIA detectada. Instalando drivers NVIDIA..."
  sudo pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils vulkan-icd-loader lib32-vulkan-icd-loader
elif echo "$GPU" | grep -qi "amd"; then
  echo "GPU AMD detectada. Instalando drivers AMD..."
  sudo pacman -S --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader
elif echo "$GPU" | grep -qi "intel"; then
  echo "GPU Intel detectada. Instalando drivers Intel..."
  sudo pacman -S --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader
else
  echo "GPU não identificada. Instalando drivers genéricos..."
  sudo pacman -S --noconfirm mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
fi

echo "Instalando bibliotecas 32 bits essenciais para jogos..."
sudo pacman -S --noconfirm lib32-glibc lib32-gcc-libs lib32-libx11 lib32-libxext lib32-libxrandr lib32-libxinerama lib32-libxcursor lib32-libxi lib32-sdl2 lib32-alsa-plugins lib32-alsa-lib lib32-openal lib32-libpulse lib32-v4l-utils lib32-glu

echo "Reiniciando Steam..."
killall steam &> /dev/null
steam &

echo "✅ Correções aplicadas para Steam e drivers GPU."

