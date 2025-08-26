#!/bin/bash
# Script para habilitar o Pac-Man (ILoveCandy) no pacman.conf

PACMAN_CONF="/etc/pacman.conf"

# Verifica se o script está rodando como root
if [[ $EUID -ne 0 ]]; then
  echo "❌ Este script precisa ser executado como root."
  echo "Use: sudo $0"
  exit 1
fi

# Faz backup antes de editar
cp "$PACMAN_CONF" "${PACMAN_CONF}.bak"

# Habilita Color (remove o # se existir)
sed -i 's/^#Color/Color/' "$PACMAN_CONF"

# Habilita ILoveCandy (se já não existir)
grep -q "^ILoveCandy" "$PACMAN_CONF"
if [[ $? -ne 0 ]]; then
  sed -i '/^Color/a ILoveCandy' "$PACMAN_CONF"
fi

echo "✅ ILoveCandy habilitado com sucesso!"
echo "👉 Agora rode 'sudo pacman -Syu' para ver o Pac-Man comendo a barra 😋"

