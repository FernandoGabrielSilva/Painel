# 🛠️ Utilitários Linux com Interface Gráfica

Este projeto é uma aplicação gráfica feita com **Python 3 + CustomTkinter** que permite executar scripts úteis para configuração e manutenção de sistemas Linux. A interface oferece botões simples para tarefas administrativas, como ativar a exibição de asteriscos no `sudo`, configurar o `fsck`, instalar o `Wine`, entre outros.

---

## 📋 Funcionalidades

| Botão                             | Ação                                                                 |
|----------------------------------|----------------------------------------------------------------------|
| Asteriscos no sudo            | Ativa a exibição de asteriscos ao digitar a senha no `sudo`.        |
| Forçar fsck no boot           | Configura o sistema para verificar automaticamente o disco no boot. |
| Configurar Fish               | Instala `fish`, `starship`, `eza`, `zoxide` e adiciona à configuração do shell. |
| Instalar Wine                 | Instala o Wine e associa arquivos `.exe` automaticamente.            |
| Atalho desinstalador do Wine | Cria atalho gráfico para o desinstalador de programas do Wine.     |
| Instalar Steam | Instala a Steam via package manager (`apt`, `pacman` e `dfn`)                     |
| Instalar GIMP | Instala o GIMP via Flatpak.                                                       |
| Instalar Inskscape | Instala o Inkscape via Flatpak.                                              |
| Instalar Krita | Instala o Krita via Flatpak.                                                     |
| Alternar tema                | Alterna entre tema claro e escuro da interface.                     |
| Instalar Neofecth                | Intala o Neofecth, personaliza e executa no terminal.                     |
| Mostrar terminal                 | Mostra/oculta o terminal embutido com logs em tempo real.           |

---

## ⚙️ Requisitos

- Sistema Linux com ambiente gráfico
- Python 3.7 ou superior
- Gerenciador de pacotes compatível: `apt`, `pacman`, `dnf` ou `zypper`

---

## 🐍 Como configurar o ambiente Python

Siga os passos abaixo para rodar o projeto:

### 1. Crie e ative o ambiente virtual (venv):

```bash
python3 -m venv venv
source venv/bin/activate
```

### 2. Instale as dependências do projeto:

```bash
pip install customtkinter
```

### 🚀 Executando o projeto

## Com o ambiente virtual ativado:

```bash
python3 painel.py
```

### 📦 Gerando um AppImage (programa portátil para Linux)

Você pode transformar o projeto em um arquivo .AppImage para rodar em qualquer sistema Linux moderno, sem precisar instalar Python ou dependências.
## ▶️ Como gerar:

##   1. Certifique-se de que seu ambiente virtual já está criado e ativado.

Se não estiver criado e ativado execulte esse codigo.

```bash
source venv/bin/activate
```

##   2. Execute o script:

```bash
chmod +x Criar AppImage.sh
./Criar AppImage.sh
```
        
### ✅ O que o script faz:

    * Cria a estrutura AppDir/ para empacotamento

    * Copia o interpretador Python e dependências dentro de AppDir/usr/lib

    * Gera o atalho .desktop da aplicação

    * Utiliza o appimagetool para gerar um arquivo .AppImage

### 📦 Resultado final:

Você terá um único arquivo [.AppImage] executável e portátil, compatível com qualquer distribuição Linux moderna.

### 📄 Licença

Este projeto é gratuito para uso pessoal, educacional e pode ser modificado livremente.
### 🙋 Autor

Desenvolvido por [FernandoGabrielSilva].

Sinta-se à vontade para contribuir, modificar ou adaptar o projeto às suas necessidades!
