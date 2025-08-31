const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const fs = require("fs");
const os = require("os");
const { spawn, exec } = require("child_process");

let mainWindow;
let sessionSudoPassword = null;

// ------------------ FUNÇÃO PRINCIPAL ------------------
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 850,
    height: 650,
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.js")
    }
  });

  mainWindow.loadFile("index.html");

  ipcMain.on("resize-window", (event, { width, height }) => {
    const win = BrowserWindow.fromWebContents(event.sender);
    if (win) win.setContentSize(width, height);
  });
}

// ------------------ MODAL DE SENHA ------------------
function createPasswordWindow(scriptName, errorMessage = "") {
  const passWin = new BrowserWindow({
    width: 450,
    height: 295,
    parent: mainWindow,
    modal: true,
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.js")
    }
  });

  passWin.loadFile("password.html", { query: { error: errorMessage } });

  const listener = (event, { password, remember }) => {
    if (remember) {
      sessionSudoPassword = password;
    }
    runScriptWithSudo(scriptName, password);
    passWin.close();
    ipcMain.removeListener("password-submitted", listener);
  };

  ipcMain.on("password-submitted", listener);
}

// ------------------ FUNÇÃO AUXILIAR ------------------
function getExecutableScript(scriptName) {
  let scriptPath = path.join(__dirname, "scripts", scriptName);

  if (scriptPath.includes(".asar")) {
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "painel-"));
    const tempScript = path.join(tempDir, scriptName);
    fs.copyFileSync(scriptPath, tempScript);
    fs.chmodSync(tempScript, 0o755);
    scriptPath = tempScript;
  } else {
    fs.chmodSync(scriptPath, 0o755);
  }

  return scriptPath;
}

// ------------------ SCRIPT NORMAL ------------------
ipcMain.on("run-script", (event, scriptName) => {
  const scriptPath = getExecutableScript(scriptName);
  const process = spawn("bash", [scriptPath]);

  process.stdout.on("data", data => {
    mainWindow.webContents.send("script-output", data.toString());
  });

  process.stderr.on("data", data => {
    mainWindow.webContents.send("script-output", `ERRO: ${data.toString()}`);
  });

  process.on("close", code => {
    mainWindow.webContents.send("script-output", `Script finalizado com código ${code}`);
  });
});

// ------------------ SCRIPT COM SUDO ------------------
ipcMain.on("request-sudo", (event, scriptName) => {
  if (sessionSudoPassword) {
    runScriptWithSudo(scriptName, sessionSudoPassword);
  } else {
    createPasswordWindow(scriptName);
  }
});

function runScriptWithSudo(scriptName, password) {
  const scriptPath = getExecutableScript(scriptName);

  // Testa senha
  exec(`echo "${password}" | sudo -S -k true`, (err) => {
    if (err) {
      createPasswordWindow(scriptName, "Senha incorreta, tente novamente.");
      return;
    }

    // Aqui executamos scripts que exigem sudo apenas para instalação, mas makepkg roda como usuário
    const command = `bash "${scriptPath}" "${password}"`;
    const proc = spawn(command, { shell: true });

    proc.stdout.on("data", (data) => {
      mainWindow.webContents.send("script-output", data.toString());
    });

    proc.stderr.on("data", (data) => {
      mainWindow.webContents.send("script-output", `ERRO: ${data.toString()}`);
    });

    proc.on("close", (code) => {
      mainWindow.webContents.send("script-output", `Script finalizado com código ${code}`);
    });
  });
}

// ------------------ EVENTOS DO APP ------------------
app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
