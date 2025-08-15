# Painel de Utilitários Linux

**Painel** é uma aplicação desktop standalone desenvolvida com Electron para facilitar a execução de scripts utilitários em sistemas Linux. A interface gráfica permite que usuários executem tarefas comuns de configuração e instalação de softwares com um único clique, exibindo a saída dos scripts em um terminal integrado. Alguns scripts requerem privilégios de superusuário (sudo), e a aplicação inclui uma janela para inserção de senha root quando necessário.

## Funcionalidades

O **Painel** oferece as seguintes funcionalidades, acessíveis por meio de botões na interface principal:

- **Ativar Asteriscos no SUDO**: Configura o terminal para exibir asteriscos ao digitar senhas com `sudo`.
- **Forçar fsck no Boot**: Configura o sistema para executar a verificação do sistema de arquivos (`fsck`) durante a inicialização.
- **Configurar Fish**: Instala e configura o shell Fish.
- **Instalar Wine**: Instala o Wine para rodar aplicativos Windows no Linux.
- **Atalho Desinstalador do Wine**: Cria um atalho para desinstalar o Wine.
- **Instalar Steam**: Instala o cliente Steam para jogos.
- **Steam Fix**: Aplica correções para problemas comuns no Steam.
- **Instalar GIMP**: Instala o editor de imagens GIMP.
- **Instalar Inkscape**: Instala o editor de gráficos vetoriais Inkscape.
- **Instalar Krita**: Instala o software de pintura digital Krita.
- **Instalar Neofetch**: Instala o Neofetch para exibir informações do sistema.
- **Instalar Fastfetch**: Instala o Fastfetch, uma alternativa ao Neofetch.
- **Instalar Yay**: Instala o Yay, um auxiliar para gerenciar pacotes AUR no Arch Linux.
- **Instalar e configurar Timeshift**: Instala e configura o Timeshift, um auxiliador de snapshots no Arch Linux. (`Precisa do Yay instalado`)
- **Instalar Node.js**: Instala o Node.js junto do npm, pnom e yarn.

### Outras Características
- **Terminal Integrado**: Exibe a saída dos scripts em tempo real, com opção de mostrar ou ocultar o terminal.
- **Suporte a Scripts com Sudo**: Para scripts que requerem privilégios de superusuário, uma janela modal solicita a senha root. Se a senha estiver incorreta, a janela é reaberta com uma mensagem de erro.
- **Interface Simples**: Interface gráfica intuitiva com botões para cada tarefa.
- **Distribuição Multi-Formato**: Suporta geração de pacotes `AppImage`, `deb` e (opcionalmente) `rpm` para diferentes distribuições Linux.

## Pré-requisitos

- **Sistema Operacional**: Linux (testado em distribuições baseadas em Debian/Ubuntu e Arch Linux).
- **Node.js e Yarn**: Necessários para desenvolvimento e build da aplicação.
- **libfuse2**: Requerido para executar o `AppImage` gerado.
  ```bash
  sudo apt install -y libfuse2  # Ubuntu/Debian
  sudo pacman -S fuse2         # Arch Linux
  sudo dnf install -y fuse-libs  # Fedora
  ```

## Instalação

1. **Clone o repositório**:
   ```bash
   git clone https://github.com/FernandoGabrielSilva/Painel.git
   cd Painel
   ```

2. **Instale as dependências**:
   ```bash
   yarn install
   ```

3. **Inicie a aplicação em modo de desenvolvimento**:
   ```bash
   yarn start
   ```

4. **Construa a aplicação para distribuição**:
   ```bash
   yarn dist
   ```
   Isso gerará pacotes `AppImage` e `deb` no diretório `dist/`. Para gerar pacotes `rpm`, instale o pacote `rpm`:
   ```bash
   sudo apt install -y rpm  # Para Ubuntu/Debian
   sudo pacman -S rpm-tools  # Para Arch Linux
   sudo dnf install -y rpm-build  # Fedora
   ```

5. **Execute o AppImage**:
   ```bash
   chmod +x dist/Painel-x86_64.AppImage
   ./dist/Painel-x86_64.AppImage
   ```

## Como Usar

1. Inicie a aplicação com `yarn start` ou execute o `AppImage` gerado.
2. Na interface principal, clique em um dos botões para executar o script desejado.
3. Para scripts que requerem `sudo` (como instalação do Wine ou Yay), uma janela será exibida solicitando a senha root.
4. A saída do script será exibida no terminal integrado. Use o botão "Mostrar Terminal" ou "Ocultar Terminal" para controlar a visibilidade.
5. Caso a senha root esteja incorreta, a janela de senha será reaberta com uma mensagem de erro.

## Estrutura do Projeto

- **`index.html`**: Interface principal com botões para executar scripts e um terminal integrado.
- **`password.html`**: Janela modal para inserção da senha root.
- **`main.js`**: Script principal do Electron, responsável por criar janelas, gerenciar processos e executar scripts.
- **`renderer.js`**: Lida com a lógica da interface, incluindo a decisão de executar scripts com ou sem `sudo`.
- **`preload.js`**: Expõe APIs seguras para comunicação entre o renderer e o processo principal.
- **`styles.css`**: Arquivo de estilos para a interface gráfica.
- **`scripts/`**: Diretório contendo os scripts Bash executados pela aplicação.

## Notas de Desenvolvimento

- **Segurança**: A aplicação usa `contextBridge` para comunicação segura entre os processos renderer e main, evitando exposição direta de APIs do Electron.
- **Scripts com Sudo**: Scripts que requerem privilégios de superusuário são identificados em `renderer.js` e executados com `sudo` após validação da senha.
- **Build**: O `electron-builder` é configurado para gerar pacotes `AppImage` e `deb`. Para suportar `rpm`, instale o `rpmbuild`.

## Licença

Este projeto está licenciado sob a licença MIT.

## Contato

Desenvolvido por Fernando Gabriel Silva. Para questões ou sugestões, entre em contato via [fernandogabrielsadasilva@gmail.com](mailto:fernandogabrielsadasilva@gmail.com).
