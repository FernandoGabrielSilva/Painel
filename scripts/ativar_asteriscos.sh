#!/bin/bash
echo "Verificando se o arquivo /etc/sudoers.d/pwfeedback existe..."

FILE="/etc/sudoers.d/pwfeedback"
if [[ -f "$FILE" ]]; then
  echo "⚠️ O arquivo '$FILE' já existe. Conteúdo atual:"
  cat "$FILE"
else
  echo "Criando o arquivo para ativar os asteriscos no sudo..."
  echo "Defaults        pwfeedback" > "$FILE"
  chmod 440 "$FILE"
  echo "✅ Asteriscos ativados com sucesso no sudo."
fi

