#!/usr/bin/env bash
# ============================================
# Instalação do Node.js LTS, npm, pnpm e yarn
# Compatível com Arch Linux e CachyOS
# Autor: Nandex Script
# ============================================

# === Função para exibir mensagens coloridas ===
msg_info()  { echo -e "\e[34m[INFO]\e[0m $1"; }
msg_ok()    { echo -e "\e[32m[OK]\e[0m $1"; }
msg_warn()  { echo -e "\e[33m[AVISO]\e[0m $1"; }
msg_error() { echo -e "\e[31m[ERRO]\e[0m $1"; }

# === Verifica se está no Arch/CachyOS ===
if ! grep -qiE "arch|cachyos" /etc/os-release; then
    msg_error "Este script só pode ser executado no Arch Linux ou CachyOS."
    exit 1
fi

# === Verifica se tem sudo ===
if ! command -v sudo &>/dev/null; then
    msg_error "O comando 'sudo' não está instalado. Instale-o primeiro."
    exit 1
fi

# === Atualiza sistema ===
msg_info "Atualizando lista de pacotes..."
sudo pacman -Syu --noconfirm || { msg_error "Falha ao atualizar o sistema."; exit 1; }

# === Instala Node.js LTS e npm ===
msg_info "Instalando Node.js LTS e npm..."
if sudo pacman -S --needed --noconfirm nodejs-lts-hydrogen npm; then
    msg_ok "Node.js e npm instalados com sucesso."
else
    msg_error "Falha ao instalar Node.js/npm."
    exit 1
fi

# === Instala pnpm ===
msg_info "Instalando pnpm..."
if sudo npm install -g pnpm; then
    msg_ok "pnpm instalado com sucesso."
else
    msg_error "Falha ao instalar pnpm."
    exit 1
fi

# === Instala yarn ===
msg_info "Instalando yarn..."
if sudo npm install -g yarn; then
    msg_ok "yarn instalado com sucesso."
else
    msg_error "Falha ao instalar yarn."
    exit 1
fi

# === Exibe versões instaladas ===
msg_info "Versões instaladas:"
node -v && npm -v && pnpm -v && yarn -v

msg_ok "Instalação concluída com sucesso!"

