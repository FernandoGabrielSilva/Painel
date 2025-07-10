#!/bin/bash

# Define the build directory
BUILD_DIR="Compiladores/CompiladorDeb/build_dir"

# Remove any existing build directory to start fresh
rm -rf "$BUILD_DIR"

# Create the necessary directories with correct permissions
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/share/icons"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/usr/lib"
mkdir -p "$BUILD_DIR/DEBIAN"
chmod -R u+w "$BUILD_DIR"

# Verify that source directory exists
if [ ! -d "AppDir/usr" ]; then
    echo "Erro: Diretório AppDir/usr não existe. Verifique a estrutura do projeto."
    exit 1
fi

# Copy the structure from AppDir/usr to build_dir/usr
rsync -av AppDir/usr/ "$BUILD_DIR/usr/" --exclude DEBIAN
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao copiar arquivos com rsync."
    exit 1
fi

# Copy additional files
cp AppDir/app.png "$BUILD_DIR/usr/share/icons/painel.png"
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao copiar app.png."
    exit 1
fi

cp AppDir/painel.desktop "$BUILD_DIR/usr/share/applications/painel.desktop"
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao copiar painel.desktop."
    exit 1
fi

# Verify and set permissions for painel.py
if [ -f "$BUILD_DIR/usr/bin/painel.py" ]; then
    chmod +x "$BUILD_DIR/usr/bin/painel.py"
else
    echo "Erro: painel.py não encontrado em $BUILD_DIR/usr/bin."
    exit 1
fi

# Create the DEBIAN/control file
cat > "$BUILD_DIR/DEBIAN/control" << EOL
Package: painel
Version: 1.0.6
Section: utils
Priority: optional
Architecture: all
Depends: python3
Maintainer: Fernando Gabriel Silva <[email protected]>
Description: Painel de utilitários Linux
EOL

# Create the debian-binary file
echo -e "2.0" > "$BUILD_DIR/debian-binary"
if [ ! -f "$BUILD_DIR/debian-binary" ]; then
    echo "Erro: Não foi possível criar o arquivo debian-binary."
    exit 1
fi
chmod 644 "$BUILD_DIR/debian-binary"

# Create the data tarball
tar -czf "$BUILD_DIR/data.tar.gz" -C "$BUILD_DIR/usr" .
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao criar data.tar.gz."
    exit 1
fi
chmod 644 "$BUILD_DIR/data.tar.gz"

# Create the control tarball
tar -czf "$BUILD_DIR/control.tar.gz" -C "$BUILD_DIR/DEBIAN" .
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao criar control.tar.gz."
    exit 1
fi
chmod 644 "$BUILD_DIR/control.tar.gz"

# Create the .deb package
ar rcs "$BUILD_DIR/Painel-x86_64.deb" "$BUILD_DIR/debian-binary" "$BUILD_DIR/control.tar.gz" "$BUILD_DIR/data.tar.gz"
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao criar o pacote .deb com ar."
    exit 1
fi

# Move the generated .deb package to the current directory
if [ -f "$BUILD_DIR/Painel-x86_64.deb" ]; then
    mv "$BUILD_DIR/Painel-x86_64.deb" .
else
    echo "Erro: Pacote .deb não foi gerado."
    exit 1
fi

# Clean up
rm -rf "$BUILD_DIR"

echo "Pacote .deb gerado com sucesso na pasta atual!"
