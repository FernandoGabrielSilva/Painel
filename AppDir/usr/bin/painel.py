#!/usr/bin/env python3
import os
import subprocess
import customtkinter as ctk
import threading
import shlex

sudo_senha = None
tema_escuro = True

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

app = ctk.CTk()  # Criado antes de qualquer função usar

class ModalSenha(ctk.CTkToplevel):
    def __init__(self, parent):
        super().__init__(parent)
        self.title("Senha de administrador")
        self.geometry("300x130")
        self.resizable(False, False)
        self.transient(parent)
        
        self.wait_visibility()  # <-- Espera janela ficar visível
        self.grab_set()         # <-- Agora o grab funciona sem erro

        self.senha = None

        label = ctk.CTkLabel(self, text="Digite sua senha:", anchor="w")
        label.pack(padx=20, pady=(15, 5), fill="x")

        self.input_senha = ctk.CTkEntry(self, show="*")
        self.input_senha.pack(padx=20, fill="x")
        self.input_senha.focus()

        btn_frame = ctk.CTkFrame(self, fg_color="transparent")
        btn_frame.pack(pady=15, fill="x")

        btn_ok = ctk.CTkButton(btn_frame, text="OK", width=80, command=self.confirmar)
        btn_ok.pack(side="left", padx=(20, 10))

        btn_cancel = ctk.CTkButton(btn_frame, text="Cancelar", width=80, command=self.cancelar)
        btn_cancel.pack(side="right", padx=(10, 20))

        self.bind("<Return>", lambda e: self.confirmar())
        self.bind("<Escape>", lambda e: self.cancelar())

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
    modo = "dark" if tema_escuro else "light"
    ctk.set_appearance_mode(modo)

def executar_como_root(script):
    global sudo_senha
    if not sudo_senha:
        senha = pedir_senha()
        if not senha:
            terminal.insert("end", "⚠️ Operação cancelada pelo usuário.\n")
            terminal.see("end")
            return
        sudo_senha = senha
    else:
        senha = sudo_senha

    def run_script():
        terminal.insert("end", "\n➡️ Executando script como root...\n\n")
        terminal.see("end")
        manter_cache = f"echo {shlex.quote(senha)} | sudo -S -v"
        subprocess.run(manter_cache, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        comando = f"echo {shlex.quote(senha)} | sudo -S bash -c {shlex.quote(script)}"
        process = subprocess.Popen(comando, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        for linha in process.stdout:
            terminal.insert("end", linha)
            terminal.see("end")

        process.wait()
        status = "\n✅ Concluído com sucesso!\n" if process.returncode == 0 else f"\n❌ Erro (código {process.returncode})\n"
        terminal.insert("end", status)
        terminal.see("end")

    threading.Thread(target=run_script, daemon=True).start()

# Scripts utilitários
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

    # 2. Configuração do fish (como usuário normal)
    config_content = '''# Configurações essenciais
starship init fish | source
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
        os.makedirs(config_dir, exist_ok=True, mode=0o755)
        
        # Verifica permissões
        if not os.access(config_dir, os.W_OK):
            raise Exception(f"Sem permissão de escrita em: {config_dir}")
        
        # Escreve o arquivo de configuração
        with open(config_file, 'w') as f:
            f.write(config_content)
        
        # Verifica se o arquivo foi criado
        if not os.path.exists(config_file):
            raise Exception("Arquivo não foi criado, sem mensagem de erro")
            
        # Verifica o conteúdo
        with open(config_file, 'r') as f:
            content = f.read()
            if config_content not in content:
                raise Exception("Conteúdo do arquivo não corresponde ao esperado")
        
        # Mensagem de sucesso
        terminal.insert("end", f"✅ Configuração do Fish concluída com sucesso!\n")
        terminal.insert("end", f"📁 Arquivo criado em: {config_file}\n")
        terminal.insert("end", f"🔍 Conteúdo verificado com sucesso\n")
        
    except Exception as e:
        terminal.insert("end", f"❌ Erro ao configurar Fish: {str(e)}\n")
        
        # Fallback: Mostra comandos para executar manualmente
        terminal.insert("end", "\n🔧 SOLUÇÃO ALTERNATIVA - Execute estes comandos manualmente:\n")
        terminal.insert("end", f"mkdir -p {config_dir}\n")
        terminal.insert("end", f"cat > {config_file} << 'EOF'\n")
        terminal.insert("end", config_content)
        terminal.insert("end", "\nEOF\n")
        
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
