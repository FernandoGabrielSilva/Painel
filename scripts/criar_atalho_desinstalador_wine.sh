#!/bin/bash
echo "Criando atalho para desinstalador do Wine..."

mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/wine-uninstaller.desktop <<EOF
[Desktop Entry]
Name=Desinstalador do Wine
Exec=wine uninstaller
Icon=wine
Terminal=false
Type=Application
Categories=Utility;
EOF

echo "Atualizando banco de dados de aplicações..."
update-desktop-database ~/.local/share/applications

echo "✅ Atalho para desinstalador criado!"

