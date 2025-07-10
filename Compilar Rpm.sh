#!/bin/bash

# Define the build directory
BUILD_DIR="Compiladores/CompiladorRpm/build_dir"

# Check for rsync (optional, fallback to cp if missing)
RSYNC_AVAILABLE=1
if ! command -v rsync &> /dev/null; then
    RSYNC_AVAILABLE=0
    echo "Aviso: rsync não está instalado. Usando cp como alternativa."
fi

# Check for gzip (optional, skip compression if missing)
GZIP_AVAILABLE=1
if ! command -v gzip &> /dev/null; then
    GZIP_AVAILABLE=0
    echo "Aviso: gzip não está instalado. O pacote não será comprimido."
fi

# Remove any existing build directory to start fresh
rm -rf "$BUILD_DIR"

# Create the necessary directories with correct permissions
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/share/icons"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/usr/lib"
mkdir -p "$BUILD_DIR/rpmmeta"
chmod -R u+w "$BUILD_DIR"

# Verify that source directory exists
if [ ! -d "AppDir/usr" ]; then
    echo "Erro: Diretório AppDir/usr não existe. Verifique a estrutura do projeto."
    exit 1
fi

# Copy the structure from AppDir/usr to build_dir/usr
if [ $RSYNC_AVAILABLE -eq 1 ]; then
    rsync -av AppDir/usr/ "$BUILD_DIR/usr/" --exclude DEBIAN
    if [ $? -ne 0 ]; then
        echo "Erro: Falha ao copiar arquivos com rsync."
        exit 1
    fi
else
    cp -r AppDir/usr/* "$BUILD_DIR/usr/"
    if [ $? -ne 0 ]; then
        echo "Erro: Falha ao copiar arquivos com cp."
        exit 1
    fi
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

# Create a metadata file (simplified .spec-like file)
cat > "$BUILD_DIR/rpmmeta/painel.spec" << EOL
Name: painel
Version: 1.0.6
Release: 1
Summary: Painel de utilitários Linux
License: MIT
Group: Applications/Utilitários
BuildArch: noarch
Requires: python3

%description
Painel gráfico para utilitários Linux, incluindo ferramentas como Wine, Steam e GIMP.

%files
/usr/bin/painel.py
/usr/share/icons/painel.png
/usr/share/applications/painel.desktop
/usr/lib/*
EOL

# Create the data archive using tar
tar -cf "$BUILD_DIR/data.tar" -C "$BUILD_DIR/usr" .
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao criar data.tar."
    exit 1
fi

# Compress the tar archive if gzip is available
if [ $GZIP_AVAILABLE -eq 1 ]; then
    gzip "$BUILD_DIR/data.tar"
    if [ $? -ne 0 ]; then
        echo "Erro: Falha ao comprimir data.tar.gz."
        exit 1
    fi
    DATA_FILE="$BUILD_DIR/data.tar.gz"
else
    DATA_FILE="$BUILD_DIR/data.tar"
fi

# Create a simple header (not a full RPM header, just metadata for extraction)
cat > "$BUILD_DIR/header" << EOL
RPMV1.0
Name: painel
Version: 1.0.6
Release: 1
Summary: Painel de utilitários Linux
EOL
cat "$BUILD_DIR/rpmmeta/painel.spec" >> "$BUILD_DIR/header"
cat "$DATA_FILE" >> "$BUILD_DIR/header"

# Rename to .rpm
mv "$BUILD_DIR/header" "$BUILD_DIR/Painel-x86_64.noarch.rpm"
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao renomear o pacote."
    exit 1
fi

# Move the generated RPM to the current directory
if [ -f "$BUILD_DIR/Painel-x86_64.noarch.rpm" ]; then
    mv "$BUILD_DIR/Painel-x86_64.noarch.rpm" .
else
    echo "Erro: Pacote .rpm não foi gerado."
    exit 1
fi

# Clean up
rm -rf "$BUILD_DIR"

echo "Pacote .rpm gerado com sucesso na pasta atual!"
