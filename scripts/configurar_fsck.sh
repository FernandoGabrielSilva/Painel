#!/bin/bash
echo "Ativando verificação de disco forçada (fsck) no boot..."

FORCE_FSCK_ARGS="fsck.mode=force fsck.repair=yes"

editar_grub() {
  GRUB_FILE="/etc/default/grub"
  if ! ls /boot/grub*/grub.cfg &>/dev/null; then
    echo "❌ GRUB não detectado."
    return 1
  fi
  echo "Editando GRUB..."
  if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE"; then
    sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"$/ $FORCE_FSCK_ARGS\"/" "$GRUB_FILE"
  else
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash $FORCE_FSCK_ARGS\"" >> "$GRUB_FILE"
  fi
  echo "Atualizando configuração do GRUB..."
  update-grub || grub-mkconfig -o /boot/grub/grub.cfg
  echo "✅ fsck ativado no boot via GRUB."
  return 0
}

editar_kernelstub() {
  if command -v kernelstub &>/dev/null; then
    echo "Editando Kernelstub..."
    kernelstub -a "$FORCE_FSCK_ARGS"
    echo "✅ kernelstub configurado."
    return 0
  fi
  return 1
}

editar_grub || editar_kernelstub || echo "⚠️ Adicione manualmente: $FORCE_FSCK_ARGS"

