#!/usr/bin/env python3
import os
import subprocess
import customtkinter as ctk
import threading
import shlex
import queue  # Novo import para a fila

sudo_senha = None
tema_escuro = True
is_executing = False  # Controle de execução
fila_comandos = queue.Queue()  # Fila para armazenar os comandos

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

app = ctk.CTk()

# Modal para pedir senha
class ModalSenha(ctk.CTkToplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.title("Senha de administrador")
        self.geometry("300x130")
        self.resizable(False, False)
        self.transient(parent)
        self.senha = None

        label = ctk.CTkLabel(self, text="Digite sua senha:", anchor="w")
        label.pack(padx=20, pady=(15, 5), fill="x")

        self.input_senha = ctk.CTkEntry(self, show="*")
        self.input_senha.pack(padx=20, fill="x")
        self.input_senha.focus()

        frame_btn = ctk.CTkFrame(self, fg_color="transparent")
        frame_btn.pack(pady=15, fill="x")

        btn_ok = ctk.CTkButton(frame_btn, text="OK", width=80, command=self.confirmar)
        btn_ok.pack(side="left", padx=(20, 10))

        btn_cancel = ctk.CTkButton(frame_btn, text="Cancelar", width=80, command=self.cancelar)
        btn_cancel.pack(side="right", padx=(10, 20))

        self.bind("<Return>", lambda e: self.confirmar())
        self.bind("<Escape>", lambda e: self.cancelar())

        self.grab_set()
        self.wait_visibility()

    def confirmar(self):
        self.senha = self.input_senha.get()
        if not self.senha:
            return
        self.grab_release()
        self.destroy()

    def cancelar(self):
        self.senha = None
        self.grab_release()
        self.destroy()

def pedir_senha():
    modal = ModalSenha(app)
    app.wait_window(modal)
    return modal.senha

def alternar_tema():
    global tema_escuro
    tema_escuro = not tema_escuro
    ctk.set_appearance_mode("dark" if tema_escuro else "light")

def mostrar_terminal_auto():
    global terminal_visivel
    if not terminal_visivel:
        terminal.grid()
        botao_toggle_terminal.configure(text="Ocultar terminal")
        texto_info.configure(text="Terminal exibido com logs.")
        terminal_visivel = True
        app.update_idletasks()

# Validar senha sudo rodando em thread, atualiza terminal com resultado
def validar_senha(senha, callback):
    def tarefa():
        def inserir(texto):
            terminal.insert("end", texto)
            terminal.see("end")
        app.after(0, inserir, "🔐 Verificando senha...\n")

        comando = f"echo {shlex.quote(senha)} | sudo -S -k true"
        processo = subprocess.run(comando, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
        if processo.returncode == 0:
            app.after(0, inserir, "✅ Senha correta!\n")
            app.after(0, callback, True)
        else:
            app.after(0, inserir, f"❌ Senha incorreta.\n{processo.stderr}\n")
            app.after(0, callback, False)

    threading.Thread(target=tarefa, daemon=True).start()

# Função para obter senha válida com até 3 tentativas
def obter_senha_valida(final_callback, tentativas=0):
    if tentativas >= 3:
        terminal.insert("end", "❌ Número máximo de tentativas excedido.\n")
        terminal.see("end")
        final_callback(None)
        return

    senha = pedir_senha()
    if not senha:
        terminal.insert("end", "⚠️ Operação cancelada pelo usuário.\n")
        terminal.see("end")
        final_callback(None)
        return

    def resultado_validacao(valida):
        if valida:
            final_callback(senha)
        else:
            mostrar_terminal_auto()
            obter_senha_valida(final_callback, tentativas + 1)

    validar_senha(senha, resultado_validacao)

# Função para executar script como root, pedindo e validando senha se necessário
def executar_como_root(script):
    global sudo_senha

    def executar_comando():
        terminal.insert("end", "\n➡️ Executando script como root...\n\n")
        terminal.see("end")

        comando = f"echo {shlex.quote(sudo_senha)} | sudo -S bash -c {shlex.quote(script)}"
        processo = subprocess.Popen(comando, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        for linha in processo.stdout:
            terminal.insert("end", linha)
            terminal.see("end")

        processo.wait()
        terminal.insert("end", "\n✅ Comando finalizado.\n" if processo.returncode == 0 else f"\n❌ Erro (code {processo.returncode})\n")
        terminal.see("end")

    def validar_callback(valida, senha):
        global sudo_senha
        if valida:
            sudo_senha = senha
            executar_comando()
        else:
            # Se senha incorreta, pede nova senha
            app.after(0, lambda: obter_senha_valida(nova_senha_callback))

    def nova_senha_callback(nova_senha):
        if nova_senha:
            # Valida nova senha em thread secundária
            def validar_nova_senha():
                comando = f"echo {shlex.quote(nova_senha)} | sudo -S -k true"
                processo = subprocess.run(comando, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                valido = processo.returncode == 0
                app.after(0, lambda: validar_callback(valido, nova_senha))
            threading.Thread(target=validar_nova_senha, daemon=True).start()
        else:
            terminal.insert("end", "⚠️ Operação cancelada.\n")
            terminal.see("end")

    def iniciar_fluxo():
        if sudo_senha is None:
            # Pede senha na thread principal
            app.after(0, lambda: obter_senha_valida(nova_senha_callback))
        else:
            # Valida senha atual em thread secundária
            def validar_atual():
                comando = f"echo {shlex.quote(sudo_senha)} | sudo -S -k true"
                processo = subprocess.run(comando, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                valido = processo.returncode == 0
                app.after(0, lambda: validar_callback(valido, sudo_senha))
            threading.Thread(target=validar_atual, daemon=True).start()

    threading.Thread(target=iniciar_fluxo, daemon=True).start()
    
def processar_fila():
    global is_executing
    if is_executing or fila_comandos.empty():
        return

    is_executing = True
    script = fila_comandos.get()

    def executar_comando():
        terminal.insert("end", "\n➡️ Executando script como root...\n\n")
        terminal.see("end")

        comando = f"echo {shlex.quote(sudo_senha)} | sudo -S bash -c {shlex.quote(script)}"
        processo = subprocess.Popen(comando, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        for linha in processo.stdout:
            terminal.insert("end", linha)
            terminal.see("end")

        processo.wait()
        terminal.insert("end", "\n✅ Comando finalizado.\n" if processo.returncode == 0 else f"\n❌ Erro (code {processo.returncode})\n")
        terminal.see("end")

        # Após terminar, liberar a execução e processar o próximo comando
        app.after(0, lambda: finalizar_comando())

    def finalizar_comando():
        global is_executing
        is_executing = False
        # Processa o próximo comando na fila
        app.after(0, processar_fila)

    def validar_callback(valida, senha):
        global sudo_senha
        if valida:
            sudo_senha = senha
            executar_comando()
        else:
            # Se senha incorreta, pede nova senha
            app.after(0, lambda: obter_senha_valida(nova_senha_callback))

    def nova_senha_callback(nova_senha):
        if nova_senha:
            # Valida nova senha em thread secundária
            def validar_nova_senha():
                comando = f"echo {shlex.quote(nova_senha)} | sudo -S -k true"
                processo = subprocess.run(comando, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                valido = processo.returncode == 0
                app.after(0, lambda: validar_callback(valido, nova_senha))
            threading.Thread(target=validar_nova_senha, daemon=True).start()
        else:
            terminal.insert("end", "⚠️ Operação cancelada.\n")
            terminal.see("end")
            finalizar_comando()  # Libera a fila mesmo se cancelado

    def iniciar_fluxo():
        if sudo_senha is None:
            # Pede senha na thread principal
            app.after(0, lambda: obter_senha_valida(nova_senha_callback))
        else:
            # Valida senha atual em thread secundária
            def validar_atual():
                comando = f"echo {shlex.quote(sudo_senha)} | sudo -S -k true"
                processo = subprocess.run(comando, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                valido = processo.returncode == 0
                app.after(0, lambda: validar_callback(valido, sudo_senha))
            threading.Thread(target=validar_atual, daemon=True).start()

    threading.Thread(target=iniciar_fluxo, daemon=True).start()

# Modificar a função executar_como_root para usar a fila
def executar_como_root(script):
    global fila_comandos
    fila_comandos.put(script)
    terminal.insert("end", f"📌 Comando adicionado à fila. Posição: {fila_comandos.qsize()}\n")
    terminal.see("end")
    mostrar_terminal_auto()
    processar_fila()

# --- Seus scripts utilitários ---

def ativar_asteriscos():
    script = """
    FILE="/etc/sudoers.d/pwfeedback"
    if [[ -f "$FILE" ]]; then
      echo "⚠️ O arquivo '$FILE' já existe. Conteúdo atual:"
      cat "$FILE"
    else
      echo "Defaults        pwfeedback" > "$FILE"
      chmod 440 "$FILE"
      echo "✅ Asteriscos ativados com sucesso no sudo."
    fi
    """
    executar_como_root(script)

def configurar_fsck():
    script = '''
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
    '''
    executar_como_root(script)

def configurar_fish():
    # 1️⃣ Primeiro instala os pacotes como root
    install_script = '''
    detect_package_manager() {
      for pm in pacman apt dnf zypper; do
        if command -v $pm &>/dev/null; then echo $pm; return; fi
      done
      echo "unknown"
    }
    
    install_packages() {
      case $1 in
        pacman) pacman -Sy --noconfirm --needed starship eza zoxide fish ;;
        apt) apt update && apt install -y gpg && \
             mkdir -p /etc/apt/keyrings && \
             wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg && \
             echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list && \
             chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list && \
             apt update && apt install -y --no-install-recommends starship eza zoxide fish ;;
        dnf) dnf install -y starship eza zoxide fish ;;
        zypper) zypper --non-interactive install -y starship eza zoxide fish ;;
        *) echo "Instale manualmente os pacotes." ;;
      esac
    }
    
    PM=$(detect_package_manager)
    install_packages "$PM"
    '''
    executar_como_root(install_script)
    
    # Definindo como padrão
    '''
    chsh -s /usr/bin/fish
    '''
    
    # Oh My Fish
    '''
    curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish
    
    omf install lambda
    '''

    # 2. Configuração do fish (como usuário normal)
    config_content = '''# Desabilita Mensagem de Bem Vindo do Fish
set -g fish_greeting ""

# Configurações essenciais
# starship init fish | source
alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"
zoxide init fish | source
'''

    # Define os caminhos antes do try para evitar UnboundLocalError
    home_dir = os.path.expanduser('~')
    config_dir = os.path.join(home_dir, '.config', 'fish')
    config_file = os.path.join(config_dir, 'config.fish')

    try:
        # Verifica se o diretório home existe
        if not os.path.exists(home_dir):
            raise Exception(f"Diretório home não encontrado: {home_dir}")
        
        # Cria diretório .config/fish com permissões corretas
        os.makedirs(config_dir, exist_ok=True)
        
        # Verifica permissões
        if not os.access(config_dir, os.W_OK):
            raise Exception(f"Sem permissão de escrita em: {config_dir}")
        
        # Verifica se o conteúdo já está presente para evitar duplicação
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                existing_content = f.read()
        else:
            existing_content = ""

        if config_content.strip() not in existing_content:
            with open(config_file, 'a') as f:  # Modo append
                f.write('\n' + config_content.strip() + '\n')
        
        # Verifica o conteúdo final
        with open(config_file, 'r') as f:
            final_content = f.read()
            if config_content.strip() not in final_content:
                raise Exception("Conteúdo não foi adicionado corretamente")
        
        # Mensagem de sucesso
        terminal.insert("end", f"✅ Configuração do Fish concluída com sucesso!\n")
        terminal.insert("end", f"📁 Arquivo editado: {config_file}\n")
        terminal.insert("end", f"🔍 Conteúdo verificado com sucesso\n")

    except Exception as e:
        terminal.insert("end", f"❌ Erro ao configurar Fish: {str(e)}\n")
        
        # Fallback: Mostra comandos para executar manualmente
        terminal.insert("end", "\n🔧 SOLUÇÃO ALTERNATIVA - Execute estes comandos manualmente:\n")
        terminal.insert("end", f"mkdir -p {config_dir}\n")
        terminal.insert("end", f"echo '{config_content.strip()}' >> {config_file}\n")

    terminal.see("end")

def instalar_wine():
    script = '''
    echo "Detectando package manager..."
    detect_pm() {
      for pm in apt pacman dnf zypper; do
        if command -v $pm &>/dev/null; then echo $pm; return; fi
      done
      echo "unsupported"
    }
    
    echo "Instalando Wine..."
    
    install_wine() {
      case "$1" in
        apt) sudo apt update && sudo apt install -y wine ;;
        pacman) sudo pacman -Sy --noconfirm wine ;;
        dnf) sudo dnf install -y wine ;;
        zypper) sudo zypper install -y wine ;;
        *) echo "Instale o wine manualmente" && exit 1 ;;
      esac
    }

    if ! command -v wine &>/dev/null; then
      PM=$(detect_pm)
      install_wine "$PM"
    fi
    echo "Execultando Winecfg..."
    winecfg
    mkdir -p ~/.local/share/applications
    echo "Criando Atalho..."
    cat > ~/.local/share/applications/wine-exe.desktop <<EOF
[Desktop Entry]
Name=Wine Windows Program Loader
Exec=wine start /unix %f
Type=Application
MimeType=application/x-ms-dos-executable;
Terminal=false
EOF
    echo "Atualizando Aplications..."
    xdg-mime default wine-exe.desktop application/x-ms-dos-executable
    echo "✅ Wine instalado e arquivos .exe associados!"
    '''
    executar_como_root(script)

def criar_atalho_desinstalador_wine():
    script = '''
    echo "Criando Atalho..."
    cat > ~/.local/share/applications/wine-uninstaller.desktop <<EOF
[Desktop Entry]
Name=Desinstalador do Wine
Exec=wine uninstaller
Icon=wine
Terminal=false
Type=Application
Categories=Utility;
EOF
    echo "Atualizando Aplications..."
    update-desktop-database ~/.local/share/applications
    echo "✅ Atalho para desinstalador criado!"
    '''
    executar_como_root(script)
    
def instalar_steam():
    script = '''
    echo "Detectando package manager..."
    detect_pm() {
      for pm in apt pacman dnf zypper; do
        if command -v $pm &>/dev/null; then echo $pm; return; fi
      done
      echo "unsupported"
    }
    
    echo "Instalando Steam.."
    
    install_steam() {
      case "$1" in
        apt) sudo apt update && sudo apt install -y steam ;;
        pacman) sudo pacman -Sy --noconfirm steam ;;
        dnf) sudo dnf install -y wsteamine ;;
        zypper) sudo zypper install -y steam ;;
        *) echo "Instale a Steam manualmente" && exit 1 ;;
      esac
    }
    
    PM=$(detect_pm)
    install_steam "$PM"
    
    echo "✅ Steam Instalada!"
    '''
    executar_como_root(script)
    
def steam_fix():
    script = '''
    
echo "🔍 Detectando GPU..."
GPU=$(lspci | grep VGA)

if echo "$GPU" | grep -qi "nvidia"; then
  echo "💻 GPU: NVIDIA detectada"
  sudo pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils vulkan-icd-loader lib32-vulkan-icd-loader
elif echo "$GPU" | grep -qi "amd"; then
  echo "💻 GPU: AMD detectada"
  sudo pacman -S --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader
elif echo "$GPU" | grep -qi "intel"; then
  echo "💻 GPU: Intel detectada"
  sudo pacman -S --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader
else
  echo "⚠️ GPU não identificada corretamente. Instalando drivers genéricos..."
  sudo pacman -S --noconfirm mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
fi

echo "📦 Instalando bibliotecas 32 bits essenciais para jogos..."
sudo pacman -S --noconfirm \
  lib32-glibc lib32-gcc-libs \
  lib32-libx11 lib32-libxext lib32-libxrandr lib32-libxinerama \
  lib32-libxcursor lib32-libxi \
  lib32-sdl2 lib32-alsa-plugins lib32-alsa-lib lib32-openal \
  lib32-libpulse lib32-v4l-utils

echo "✅ Tudo instalado. Reiniciando Steam..."
killall steam &> /dev/null
steam &

echo "🚀 Pronto! Tente abrir seu jogo novamente."
    '''
    executar_como_root(script)
    
def instalar_gimp():
    script = '''    
    echo "Instalando Gimp.."
    flatpak install -y --noninteractive flathub org.gimp.GIMP
    
    echo "✅ GIMP Instalado!"
    '''
    executar_como_root(script)
    
def instalar_inkscape():
    script = '''    
    echo "Instalando Inkscape."
    flatpak install -y --noninteractive flathub org.inkscape.Inkscape
    
    echo "✅ Inkscape Instalado!"
    '''
    executar_como_root(script)
    
def instalar_krita():
    script = '''    
    echo "Instalando Krita.."
    flatpak install -y --noninteractive flathub org.kde.krita
    
    echo "✅ Krita Instalado!"
    '''
    executar_como_root(script)
    
def instalar_neofetch():
    script = r'''
echo "🔍 Detectando gerenciador de pacotes..."
detect_pm() {
  for pm in apt pacman dnf zypper; do
    if command -v $pm &>/dev/null; then echo $pm; return; fi
  done
  echo "unsupported"
}

install_neofetch() {
  case "$1" in
    apt) sudo apt update && sudo apt install -y neofetch ;;
    pacman) sudo pacman -Sy --noconfirm neofetch ;;
    dnf) sudo dnf install -y neofetch ;;
    zypper) sudo zypper install -y neofetch ;;
    *) echo "❌ Gerenciador não suportado. Instale o Neofetch manualmente." && exit 1 ;;
  esac
}

if ! command -v neofetch &>/dev/null; then
  PM=$(detect_pm)
  install_neofetch "$PM"
else
  echo "✅ Neofetch já está instalado."
fi

echo "🛠️ Criando configuração personalizada..."
mkdir -p ~/.config/neofetch
cat > ~/.config/neofetch/config.conf << 'EOF'
# Source: https://github.com/Chick2D/neofetch-themes/
# Made by https://github.com/tralph3 
# Customization Wiki https://github.com/dylanaraps/neofetch/wiki/Customizing-Info

# Colour config is here and in .zshrc

print_info() {
    info title
    info underline

    prin "$(color 12)╭──────────── $(color 10)Software$(color 12) ────────────"
    info "$(color 12)│ $(color 14)OS" distro
    info "$(color 12)│ $(color 14)Kernel" kernel
    info "$(color 12)│ $(color 14)Packages" packages
    info "$(color 12)│ $(color 14)Shell" shell
    info "$(color 12)│ $(color 14)DE" de
    info "$(color 12)│ $(color 14)Terminal" term
    info "$(color 12)│ $(color 14)Local IP" local_ip
    prin "$(color 12)├──────────── $(color 10)Hardware$(color 12) ────────────"
    info "$(color 12)│ $(color 14)Host" model
    info "$(color 12)│ $(color 14)CPU" cpu
    info "$(color 12)│ $(color 14)GPU" gpu
    info "$(color 12)│ $(color 14)Memory" memory
    info "$(color 12)│ $(color 14)Disk" disk
    prin "$(color 12)├───────────── $(color 10)Uptime$(color 12) ─────────────"
    info "$(color 12)│" uptime
    prin "$(color 12)╰──────────────────────────────────"

    info cols

    # Defaults

    # info "OS" distro
    # info "Host" model
    # info "Kernel" kernel
    # info "Uptime" uptime
    # info "Packages" packages
    # info "Shell" shell
    # info "Resolution" resolution
    # info "DE" de
    # info "WM" wm
    # info "WM Theme" wm_theme
    # info "Theme" theme
    # info "Icons" icons
    # info "Terminal" term
    # info "Terminal Font" term_font
    # info "CPU" cpu
    # info "GPU" gpu
    # info "Memory" memory

    # info "GPU Driver" gpu_driver  # Linux/macOS only
    # info "CPU Usage" cpu_usage
    # info "Disk" disk
    # info "Battery" battery
    # info "Font" font
    # info "Song" song
    # [[ "$player" ]] && prin "Music Player" "$player"
    # info "Local IP" local_ip
    # info "Public IP" public_ip
    # info "Users" users
    # info "Locale" locale  # This only works on glibc systems.

    # info cols

}

# To know what these functions mean, go to the Customization Wiki on top

title_fqdn="off"
kernel_shorthand="on"
distro_shorthand="on"
os_arch="off"
uptime_shorthand="off"
memory_percent="off"
memory_unit="mib"
package_managers="on"
shell_path="off"
shell_version="on"
cpu_brand="on"
cpu_speed="on"
cpu_cores="logical"
cpu_temp="off"
gpu_type="all"
refresh_rate="on"
gtk_shorthand="on"
gtk2="on"
gtk3="on"
public_ip_host="http://ident.me"
public_ip_timeout=2
de_version="on"
disk_subtitle="dir"
disk_percent="on"
music_player="auto"
song_format="%artist% - %title%"
mpc_args=()
colors=(distro)
underline_enabled="on"
underline_char="¨"
separator="›"
color_blocks="on"
block_width=3
block_height=1
col_offset="auto"
bar_char_elapsed="-"
bar_char_total="="
bar_border="on"
bar_length=15
bar_color_elapsed="distro"
bar_color_total="distro"
cpu_display="off"
memory_display="off"
battery_display="off"
disk_display="off"
image_source="auto"
ascii_distro="auto"
ascii_bold="on"
image_loop="off"
thumbnail_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/thumbnails/neofetch"
crop_mode="normal"
crop_offset="center"
image_size="auto"
gap=3
yoffset=0
xoffset=0
background_color=
stdout="off"
EOF

echo "🎉 Neofetch instalado e configurado com sucesso!"
'''
    executar_como_root(script)
    
    # 2. Configuração do fish (como usuário normal)
    config_content = '''
    neofetch
    '''

    # Define os caminhos antes do try para evitar UnboundLocalError
    home_dir = os.path.expanduser('~')
    config_dir = os.path.join(home_dir, '.config', 'fish')
    config_file = os.path.join(config_dir, 'config.fish')

    try:
        # Verifica se o diretório home existe
        if not os.path.exists(home_dir):
            raise Exception(f"Diretório home não encontrado: {home_dir}")
        
        # Cria diretório .config/fish com permissões corretas
        os.makedirs(config_dir, exist_ok=True)
        
        # Verifica permissões
        if not os.access(config_dir, os.W_OK):
            raise Exception(f"Sem permissão de escrita em: {config_dir}")
        
        # Verifica se o conteúdo já está presente para evitar duplicação
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                existing_content = f.read()
        else:
            existing_content = ""

        if config_content.strip() not in existing_content:
            with open(config_file, 'a') as f:  # Modo append
                f.write('\n' + config_content.strip() + '\n')
        
        # Verifica o conteúdo final
        with open(config_file, 'r') as f:
            final_content = f.read()
            if config_content.strip() not in final_content:
                raise Exception("Conteúdo não foi adicionado corretamente")
        
        # Mensagem de sucesso
        terminal.insert("end", f"✅ Configuração do Neofecth concluída com sucesso!\n")
        terminal.insert("end", f"📁 Arquivo editado: {config_file}\n")
        terminal.insert("end", f"🔍 Conteúdo verificado com sucesso\n")

    except Exception as e:
        terminal.insert("end", f"❌ Erro ao configurar Neofecth: {str(e)}\n")
        
        # Fallback: Mostra comandos para executar manualmente
        terminal.insert("end", "\n🔧 SOLUÇÃO ALTERNATIVA - Execute estes comandos manualmente:\n")
        terminal.insert("end", f"mkdir -p {config_dir}\n")
        terminal.insert("end", f"echo '{config_content.strip()}' >> {config_file}\n")

    terminal.see("end")
    
def instalar_fastfetch():
    script = r'''
echo "🔍 Detectando gerenciador de pacotes..."
detect_pm() {
  for pm in apt pacman dnf zypper; do
    if command -v $pm &>/dev/null; then echo $pm; return; fi
  done
  echo "unsupported"
}

install_neofetch() {
  case "$1" in
    apt) sudo apt update && sudo apt install -y fastfetch ;;
    pacman) sudo pacman -Sy --noconfirm fastfetch ;;
    dnf) sudo dnf install -y fastfetch ;;
    zypper) sudo zypper install -y fastfetch ;;
    *) echo "❌ Gerenciador não suportado. Instale o Neofetch manualmente." && exit 1 ;;
  esac
}

if ! command -v fastfetch &>/dev/null; then
  PM=$(detect_pm)
  install_fastfetch "$PM"
else
  echo "✅ Fastfetch já está instalado."
fi
'''
    executar_como_root(script)
    
    # 2. Configuração do fish (como usuário normal)
    config_content = '''
    fastfetch
    '''

    # Define os caminhos antes do try para evitar UnboundLocalError
    home_dir = os.path.expanduser('~')
    config_dir = os.path.join(home_dir, '.config', 'fish')
    config_file = os.path.join(config_dir, 'config.fish')

    try:
        # Verifica se o diretório home existe
        if not os.path.exists(home_dir):
            raise Exception(f"Diretório home não encontrado: {home_dir}")
        
        # Cria diretório .config/fish com permissões corretas
        os.makedirs(config_dir, exist_ok=True)
        
        # Verifica permissões
        if not os.access(config_dir, os.W_OK):
            raise Exception(f"Sem permissão de escrita em: {config_dir}")
        
        # Verifica se o conteúdo já está presente para evitar duplicação
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                existing_content = f.read()
        else:
            existing_content = ""

        if config_content.strip() not in existing_content:
            with open(config_file, 'a') as f:  # Modo append
                f.write('\n' + config_content.strip() + '\n')
        
        # Verifica o conteúdo final
        with open(config_file, 'r') as f:
            final_content = f.read()
            if config_content.strip() not in final_content:
                raise Exception("Conteúdo não foi adicionado corretamente")
        
        # Mensagem de sucesso
        terminal.insert("end", f"✅ Configuração do Neofecth concluída com sucesso!\n")
        terminal.insert("end", f"📁 Arquivo editado: {config_file}\n")
        terminal.insert("end", f"🔍 Conteúdo verificado com sucesso\n")

    except Exception as e:
        terminal.insert("end", f"❌ Erro ao configurar Neofecth: {str(e)}\n")
        
        # Fallback: Mostra comandos para executar manualmente
        terminal.insert("end", "\n🔧 SOLUÇÃO ALTERNATIVA - Execute estes comandos manualmente:\n")
        terminal.insert("end", f"mkdir -p {config_dir}\n")
        terminal.insert("end", f"echo '{config_content.strip()}' >> {config_file}\n")

    terminal.see("end")
    
def instalar_yay():
    # 1️⃣ Primeiro instala os pacotes como root
    install_script = '''
    sudo pacman -S --needed git base-devel --noconfirm
    
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    
    cd yay
    makepkg -si --noconfirm
    '''
    executar_como_root(install_script)

# Interface principal
app.title("🛠️ Utilitários Linux")
app.minsize(600, 300)
app.grid_rowconfigure(0, weight=0)
app.grid_rowconfigure(1, weight=0)
app.grid_rowconfigure(2, weight=0)
app.grid_rowconfigure(3, weight=0)
app.grid_rowconfigure(4, weight=1)
app.grid_columnconfigure(0, weight=1)

frame_botoes = ctk.CTkFrame(app)
frame_botoes.grid(row=0, column=0, pady=12, padx=12, sticky="ew")
frame_botoes.grid_columnconfigure((0, 1), weight=1)

botoes = [
    ("🔐 Asteriscos no sudo", ativar_asteriscos),
    ("🧠 Forçar fsck no boot", configurar_fsck),
    ("🐟 Configurar Fish", configurar_fish),
    ("🍷 Instalar Wine", instalar_wine),
    ("❌ Atalho desinstalador do Wine", criar_atalho_desinstalador_wine),
    ("🎮 Instalar Steam", instalar_steam),
    ("🎮 Steam Fix", steam_fix),
    ("🖼 Instalar GIMP", instalar_gimp),
    ("🙂 Instalar Inskscape", instalar_inkscape),
    ("💫 Instalar Krita", instalar_krita),
    ("💫 Instalar Neofecth", instalar_neofetch),
    ("💫 Instalar Fastfecth", instalar_fastfetch),
    ("💫 Instalar Yay", instalar_yay),
]

for i, (texto, acao) in enumerate(botoes):
    botao = ctk.CTkButton(frame_botoes, text=texto, command=acao)
    botao.grid(row=i//2, column=i%2, padx=10, pady=8, sticky="ew")

botao_tema = ctk.CTkButton(app, text="🌗 Alternar tema", command=alternar_tema)
botao_tema.grid(row=1, column=0, padx=12, pady=5, sticky="ew")

texto_info = ctk.CTkLabel(app, text="Clique para exibir ou ocultar o terminal", anchor="center")
texto_info.grid(row=2, column=0, padx=12, sticky="ew")

botao_toggle_terminal = ctk.CTkButton(app, text="Mostrar terminal")
botao_toggle_terminal.grid(row=3, column=0, padx=12, pady=(0, 10), sticky="ew")

terminal = ctk.CTkTextbox(app, height=250, wrap="word", font=("Courier New", 11))
terminal.grid(row=4, column=0, padx=12, pady=(0, 12), sticky="nsew")
terminal.grid_remove()

terminal_visivel = False

def toggle_terminal():
    global terminal_visivel
    if terminal_visivel:
        terminal.grid_remove()
        botao_toggle_terminal.configure(text="Mostrar terminal")
        texto_info.configure(text="Clique para exibir ou ocultar o terminal")
    else:
        terminal.grid()
        botao_toggle_terminal.configure(text="Ocultar terminal")
        texto_info.configure(text="Terminal exibido com logs.")
    terminal_visivel = not terminal_visivel
    app.update_idletasks()

botao_toggle_terminal.configure(command=toggle_terminal)

# Botão para testar modal de senha
def testar_modal():
    senha = pedir_senha()
    if senha:
        terminal.insert("end", f"Senha digitada: {senha}\n")
    else:
        terminal.insert("end", "Senha cancelada.\n")
    terminal.see("end")

# botao_teste = ctk.CTkButton(app, text="🧪 Testar Modal de Senha", command=testar_modal)
# botao_teste.grid(row=5, column=0, padx=12, pady=5, sticky="ew")

# Inicia a aplicação
app.mainloop()
