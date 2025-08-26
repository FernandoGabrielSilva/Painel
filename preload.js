const { contextBridge, ipcRenderer } = require("electron");
const fs = require("fs");
const path = require("path");

contextBridge.exposeInMainWorld("electronAPI", {
  runScript: (script) => ipcRenderer.send("run-script", script),
  requestSudo: (script) => ipcRenderer.send("request-sudo", script),
  submitPassword: (password) => ipcRenderer.send("password-submitted", password),
  onOutput: (callback) => ipcRenderer.on("script-output", (event, data) => callback(data)),
  resizeWindow: (width, height) => ipcRenderer.send("resize-window", { width, height }),

  // Nova função para carregar o JSON
  loadScripts: () => {
    const scriptsPath = path.join(__dirname, "scripts.json");
    const data = fs.readFileSync(scriptsPath, "utf-8");
    return JSON.parse(data);
  }
});

