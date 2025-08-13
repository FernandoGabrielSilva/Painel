const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const { spawn, exec } = require("child_process");

let mainWindow;

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
      if (win) {
        win.setContentSize(width, height);
      }
    });
}

function createPasswordWindow(scriptName, errorMessage = "") {
  const passWin = new BrowserWindow({
    width: 450,
    height: 250,
    parent: mainWindow,
    modal: true,
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.js")
    }
  });

  // Passa a mensagem de erro como query string
  passWin.loadFile("password.html", { query: { error: errorMessage } });

  ipcMain.once("password-submitted", (event, password) => {
    runScriptWithSudo(scriptName, password);
    passWin.close();
  });
  
  ipcMain.on("resize-window", (event, { width, height }) => {
      const win = BrowserWindow.fromWebContents(event.sender);
      if (win) {
        win.setContentSize(width, height);
      }
    });
}

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

// Script normal
ipcMain.on("run-script", (event, scriptName) => {
  runScript(scriptName);
});

function runScript(scriptName) {
  const scriptPath = path.join(__dirname, "scripts", scriptName);
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
}

// Script com sudo
ipcMain.on("request-sudo", (event, scriptName) => {
  createPasswordWindow(scriptName);
});

function runScriptWithSudo(scriptName, password) {
  const scriptPath = path.join(__dirname, "scripts", scriptName);

  // Verifica senha primeiro
  exec(`echo "${password}" | sudo -S -k true`, (err) => {
    if (err) {
      // Se errar, abre novamente a janela pedindo senha
      createPasswordWindow(scriptName, "Senha incorreta, tente novamente.");
      return;
    }

    // Senha correta, executa script
    const command = `echo "${password}" | sudo -S bash "${scriptPath}"`;
    const proc = exec(command);

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

