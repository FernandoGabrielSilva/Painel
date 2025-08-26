#!/bin/bash

FILE="/etc/sudoers.d/pwfeedback"

echo "Verificando o arquivo '$FILE'..."

# Cria o arquivo se não existir
if [[ ! -f "$FILE" ]]; then
  echo "Criando o arquivo '$FILE'..."
  touch "$FILE"
  chmod 440 "$FILE"
fi

# Verifica se a linha já existe
if grep -qx "Defaults        pwfeedback" "$FILE"; then
  echo "A linha 'Defaults        pwfeedback' já existe no arquivo."
else
  echo "Adicionando 'Defaults        pwfeedback' ao arquivo..."
  echo "Defaults        pwfeedback" >> "$FILE"
fi

echo "✅ Configuração de asteriscos no sudo concluída."

