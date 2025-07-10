#!/bin/bash

# Define the build directory
BUILD_DIR="Compiladores/CompiladorAppImage/build_dir"

# Check for rsync (optional, fallback to cp if missing)
RSYNC_AVAILABLE=1
if ! command -v rsync &> /dev/null; then
    RSYNC_AVAILABLE=0
    echo "Aviso: rsync não está instalado. Usando cp como alternativa."
fi

# Remove any existing build directory to start fresh
rm -rf "$BUILD_DIR"

# Create the necessary directories with correct permissions
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/share/icons"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/usr/lib"
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

# Verify that Python executable and libraries exist
if [ ! -f "$BUILD_DIR/usr/bin/python3.13/bin/python3.13" ]; then
    echo "Erro: Executável python3.13 não encontrado em $BUILD_DIR/usr/bin/python3.13/bin/python3.13."
    exit 1
fi
if [ ! -f "$BUILD_DIR/usr/lib/libtk8.6.so" ] || [ ! -d "$BUILD_DIR/usr/lib/tk8.6" ] || [ ! -d "$BUILD_DIR/usr/lib/tcl8.6" ]; then
    echo "Erro: Bibliotecas necessárias (libtk8.6.so, tcl8.6, tk8.6) não encontradas em $BUILD_DIR/usr/lib."
    exit 1
fi
if [ ! -d "$BUILD_DIR/usr/lib/python3.13/site-packages" ]; then
    echo "Erro: Diretório python3.13/site-packages não encontrado em $BUILD_DIR/usr/lib."
    exit 1
fi

# Create AppRun script with proper environment setup
cat > "$BUILD_DIR/AppRun" << 'EOL'
#!/bin/bash

# Get the directory where the AppImage is extracted
TEMP_DIR="/tmp/Painel-$(date +%s)"
mkdir -p "$TEMP_DIR"

# Extract the tar archive to a temporary directory
tail -n +__EXTRACT_LINE__ "$0" | tar -x -C "$TEMP_DIR"
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao extrair o conteúdo do AppImage."
    exit 1
fi

# Set up environment to use bundled libraries
export LD_LIBRARY_PATH="$TEMP_DIR/usr/lib:$LD_LIBRARY_PATH"
export PYTHONPATH="$TEMP_DIR/usr/lib/python3.13/site-packages:$PYTHONPATH"
export TCL_LIBRARY="$TEMP_DIR/usr/lib/tcl8.6"
export TK_LIBRARY="$TEMP_DIR/usr/lib/tk8.6"

# Block system themes/icons
unset GTK_PATH XDG_DATA_DIRS

# Run the application
exec "$TEMP_DIR/usr/bin/python3.13/bin/python3.13" "$TEMP_DIR/usr/bin/painel.py" "$@"

# Exit (this line is not reached due to exec)
exit 0
EOL

# Set permissions for AppRun
chmod +x "$BUILD_DIR/AppRun"

# Create the data archive using tar
tar -cf "$BUILD_DIR/data.tar" -C "$BUILD_DIR" usr AppRun
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao criar data.tar."
    exit 1
fi

# Create the AppImage (self-extracting script)
APPIMAGE_FILE="Painel-x86_64.AppImage"
TEMP_APPIMAGE="$BUILD_DIR/temp.AppImage"
cat "$BUILD_DIR/AppRun" > "$TEMP_APPIMAGE"
echo "__TAR_START__" >> "$TEMP_APPIMAGE"
cat "$BUILD_DIR/data.tar" >> "$TEMP_APPIMAGE"

# Verify the temporary AppImage file exists
if [ ! -f "$TEMP_APPIMAGE" ]; then
    echo "Erro: Arquivo temporário $TEMP_APPIMAGE não foi criado."
    exit 1
fi

# Calculate the number of lines to skip (header lines before tar archive)
START_LINE=$(grep -a -n "^__TAR_START__$" "$TEMP_APPIMAGE" | cut -d: -f1)
if [ -z "$START_LINE" ]; then
    echo "Erro: Marcador __TAR_START__ não encontrado em $TEMP_APPIMAGE."
    echo "Conteúdo inicial de $TEMP_APPIMAGE:"
    head -n 20 "$TEMP_APPIMAGE"
    exit 1
fi
EXTRACT_LINE=$((START_LINE + 1))

# Replace __EXTRACT_LINE__ with the calculated line number
sed -i "s/__EXTRACT_LINE__/$EXTRACT_LINE/" "$TEMP_APPIMAGE"
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao substituir __EXTRACT_LINE__."
    exit 1
fi

# Rename to final AppImage
mv "$TEMP_APPIMAGE" "$BUILD_DIR/$APPIMAGE_FILE"
if [ $? -ne 0 ]; then
    echo "Erro: Falha ao renomear o AppImage."
    exit 1
fi

# Set permissions for the AppImage
chmod +x "$BUILD_DIR/$APPIMAGE_FILE"

# Move the generated AppImage to the current directory
if [ -f "$BUILD_DIR/$APPIMAGE_FILE" ]; then
    mv "$BUILD_DIR/$APPIMAGE_FILE" .
else
    echo "Erro: AppImage não foi gerado."
    exit 1
fi

# Clean up
rm -rf "$BUILD_DIR"

echo "AppImage gerado com sucesso na pasta atual!"
