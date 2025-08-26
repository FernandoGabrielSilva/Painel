#!/bin/bash
echo "[INFO] Detectando gerenciador de pacotes..."

# Detecta gerenciador de pacotes
detect_pm() {
  for pm in apt pacman dnf zypper; do
    if command -v "$pm" &>/dev/null; then
      echo "$pm"
      return
    fi
  done
  echo "unsupported"
}

# Instala Fastfetch
install_fastfetch() {
  case "$1" in
    apt)
      echo "[INFO] Instalando Fastfetch via apt..."
      apt update
      apt install -y fastfetch
      ;;
    pacman)
      echo "[INFO] Instalando Fastfetch via pacman..."
      pacman -Sy --noconfirm fastfetch
      ;;
    dnf)
      echo "[INFO] Instalando Fastfetch via dnf..."
      dnf install -y fastfetch
      ;;
    zypper)
      echo "[INFO] Instalando Fastfetch via zypper..."
      zypper install -y fastfetch
      ;;
    *)
      echo "[ERRO] Gerenciador de pacotes não suportado. Instale Fastfetch manualmente."
      exit 1
      ;;
  esac
}

# Adiciona Fastfetch a um arquivo de configuração
add_fastfetch() {
  local rc_file="$1"
  local shell_name="$2"

  echo "[INFO] Configurando Fastfetch para $shell_name em $rc_file..."

  # Garante que o diretório e o arquivo existam
  mkdir -p "$(dirname "$rc_file")"
  if ! touch "$rc_file" 2>/dev/null; then
    echo "[ERRO] Não foi possível criar ou acessar $rc_file. Verifique as permissões."
    return 1
  fi

  # Define permissões corretas para o usuário nandex
  chown nandex:nandex "$rc_file"
  chmod 644 "$rc_file"

  # Remove linhas antigas de fastfetch
  if [ -f "$rc_file" ]; then
    sed -i '/fastfetch/d' "$rc_file"
  fi

  if [ "$shell_name" = "fish" ]; then
    echo "[INFO] Processando Fish shell..."
    tmp_file=$(mktemp)
    inside_block=0
    added=0

    # Se o arquivo está vazio, cria um novo bloco interativo
    if [ ! -s "$rc_file" ]; then
      echo "[INFO] Arquivo $rc_file está vazio. Criando novo bloco interativo."
      echo -e "if status is-interactive\n    fastfetch\nend" > "$tmp_file"
      added=1
    else
      # Lê o arquivo linha por linha
      while IFS= read -r line || [ -n "$line" ]; do
        # Adiciona fastfetch antes do 'end' do bloco interativo
        if echo "$line" | grep -E '^[[:space:]]*end[[:space:]]*$' >/dev/null && [ $inside_block -eq 1 ] && [ $added -eq 0 ]; then
          echo "[DEBUG] Adicionando fastfetch antes do 'end'."
          echo "    fastfetch" >> "$tmp_file"
          added=1
        fi
        # Escreve a linha atual no arquivo temporário
        echo "$line" >> "$tmp_file"
        # Verifica se a linha contém o início do bloco interativo
        if echo "$line" | grep -E '^[[:space:]]*if[[:space:]]+status[[:space:]]+is-interactive' >/dev/null; then
          echo "[DEBUG] Bloco interativo encontrado: $line"
          inside_block=1
        fi
      done < "$rc_file"

      # Se nenhum bloco interativo foi encontrado, adiciona um novo
      if [ $added -eq 0 ]; then
        echo "[INFO] Nenhum bloco interativo encontrado. Adicionando novo bloco."
        echo -e "\nif status is-interactive\n    fastfetch\nend" >> "$tmp_file"
      fi
    fi

    # Exibe o conteúdo do arquivo temporário para depuração
    echo "[DEBUG] Conteúdo do arquivo temporário ($tmp_file):"
    cat "$tmp_file"

    # Substitui o arquivo original
    if mv "$tmp_file" "$rc_file" 2>/dev/null; then
      # Define permissões corretas após a substituição
      chown nandex:nandex "$rc_file"
      chmod 644 "$rc_file"
      echo "[OK] Fastfetch adicionado com sucesso em $rc_file"
    else
      echo "[ERRO] Falha ao substituir $rc_file. Verifique as permissões."
      return 1
    fi
  else
    echo -e "\n# Inicia Fastfetch automaticamente\nfastfetch" >> "$rc_file"
    # Define permissões corretas
    chown nandex:nandex "$rc_file"
    chmod 644 "$rc_file"
    echo "[OK] Fastfetch adicionado com sucesso em $rc_file"
  fi
}

# Configura Fastfetch para todos os shells instalados
setup_fastfetch_for_installed_shells() {
  for sh in bash zsh fish; do
    if command -v "$sh" &>/dev/null; then
      echo "[INFO] Shell $sh detectado."
      case "$sh" in
        bash)
          add_fastfetch "/home/nandex/.bashrc" "bash"
          ;;
        zsh)
          add_fastfetch "/home/nandex/.zshrc" "zsh"
          ;;
        fish)
          add_fastfetch "/home/nandex/.config/fish/config.fish" "fish"
          ;;
      esac
    else
      echo "[INFO] Shell $sh não encontrado. Pulando configuração."
    fi
  done
}

# Instala Fastfetch se não existir
if ! command -v fastfetch &>/dev/null; then
  PM=$(detect_pm)
  install_fastfetch "$PM"
else
  echo "[INFO] Fastfetch já está instalado."
fi

# Configura Fastfetch nos shells instalados
setup_fastfetch_for_installed_shells

echo "[FINALIZADO] Abra um novo terminal para ver o Fastfetch em ação."
