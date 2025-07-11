#!/bin/bash

APPDIR="$(dirname "$(realpath "$0")")"
ZENITY="$APPDIR/Compilar/usr/bin/Compiladores/Compilar/zenity"
TEMP_LOG=$(mktemp) # Arquivo temporário para capturar a saída

# Check if zenity exists, fallback to terminal prompt
if [ ! -x "$ZENITY" ]; then
    if command -v zenity &> /dev/null; then
        ZENITY="zenity"
    else
        echo "Aviso: zenity não encontrado em $APPDIR/Compilar/usr/bin/Compiladores/Compilar/zenity ou no sistema." > "$TEMP_LOG"
        echo "Usando prompt de terminal." >> "$TEMP_LOG"
        ZENITY="none"
    fi
fi

function compilar_appimage() {
    # Redirecionar saída para o arquivo temporário
    exec 3>&1 4>&2
    exec 1>>"$TEMP_LOG" 2>&1

    # Define the build directory
    BUILD_DIR="Compilar/usr/bin/Compiladores/CompiladorAppImage/build_dir"

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
        echo "Erro: Bibliotecas necessárias \(libtk8.6.so, tcl8.6, tk8.6\) não encontradas em $BUILD_DIR/usr/lib."
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

    # Mover o arquivo gerado para a pasta Executaveis
    if [ -f "$APPIMAGE_FILE" ]; then
        mv "$APPIMAGE_FILE" Executaveis/
        if [ $? -eq 0 ]; then
            echo "AppImage movido para a pasta Executaveis com sucesso!"
        else
            echo "Erro: Falha ao mover o AppImage para a pasta Executaveis."
            exit 1
        fi
    fi

    # Clean up
    rm -rf "$BUILD_DIR"

    echo "AppImage gerado com sucesso!"
    exec 1>&3 2>&4
}

function compilar_deb() {
    exec 3>&1 4>&2
    exec 1>>"$TEMP_LOG" 2>&1

    # Define the build directory
    BUILD_DIR="Compilar/usr/bin/Compiladores/CompiladorDeb/build_dir"

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
Depends: python3, tk
Maintainer: Fernando Gabriel Silva <fernandogabriel.silva@outlook.com>
Description: Painel de utilitários Linux
EOL

    # Create the debian-binary file
    echo "2.0" > "$BUILD_DIR/debian-binary"
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

    # Mover o arquivo gerado para a pasta Executaveis
    if [ -f "Painel-x86_64.deb" ]; then
        mv "Painel-x86_64.deb" Executaveis/
        if [ $? -eq 0 ]; then
            echo "Pacote .deb movido para a pasta Executaveis com sucesso!"
        else
            echo "Erro: Falha ao mover o pacote .deb para a pasta Executaveis."
            exit 1
        fi
    fi

    # Clean up
    rm -rf "$BUILD_DIR"

    echo "Pacote .deb gerado com sucesso!"
    exec 1>&3 2>&4
}

function compilar_rpm() {
    exec 3>&1 4>&2
    exec 1>>"$TEMP_LOG" 2>&1

    # Define the build directory
    BUILD_DIR="Compilar/usr/bin/Compiladores/CompiladorRpm/build_dir"

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
Requires: python3, tk

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

    # Mover o arquivo gerado para a pasta Executaveis
    if [ -f "Painel-x86_64.noarch.rpm" ]; then
        mv "Painel-x86_64.noarch.rpm" Executaveis/
        if [ $? -eq 0 ]; then
            echo "Pacote .rpm movido para a pasta Executaveis com sucesso!"
        else
            echo "Erro: Falha ao mover o pacote .rpm para a pasta Executaveis."
            exit 1
        fi
    fi

    # Clean up
    rm -rf "$BUILD_DIR"

    echo "Pacote .rpm gerado com sucesso!"
    exec 1>&3 2>&4
}

# Função para executar a compilação e exibir o log
function run_and_show_output() {
    local cmd="$1"
    # Limpar o arquivo de log temporário
    : > "$TEMP_LOG"

    if [ "$ZENITY" != "none" ]; then
        # Executar a compilação em background e exibir a saída em tempo real
        $cmd &
        COMPILATION_PID=$!
        tail -f "$TEMP_LOG" | "$ZENITY" --text-info --title="Saída do Terminal" --width=600 --height=400 --auto-scroll
        # Aguardar a conclusão da compilação
        wait $COMPILATION_PID
    else
        # No terminal, executar a compilação e mostrar a saída
        $cmd
        cat "$TEMP_LOG"
    fi
}

# Menu principal com loop
while true; do
    if [ "$ZENITY" = "none" ]; then
        echo "Selecione uma opção:"
        echo "1) Compilar AppImage"
        echo "2) Compilar Deb"
        echo "3) Compilar Rpm"
        echo "4) Sair"
        read -p "Digite o número da opção: " choice
        case "$choice" in
            1) run_and_show_output "compilar_appimage" ;;
            2) run_and_show_output "compilar_deb" ;;
            3) run_and_show_output "compilar_rpm" ;;
            4|*) rm -f "$TEMP_LOG"; exit 0 ;;
        esac
    else
        opcao=$("$ZENITY" --list \
            --title="🛠️ Compilador Linux" \
            --column="Opção" --width=400 --height=300 \
            "Compilar AppImage" \
            "Compilar Deb" \
            "Compilar Rpm" \
            "Sair")
        case "$opcao" in
            "Compilar AppImage") run_and_show_output "compilar_appimage" ;;
            "Compilar Deb") run_and_show_output "compilar_deb" ;;
            "Compilar Rpm") run_and_show_output "compilar_rpm" ;;
            "Sair"|*) rm -f "$TEMP_LOG"; exit 0 ;;
        esac
    fi
done
