const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  runScript: (script) => ipcRenderer.send("run-script", script),
  requestSudo: (script) => ipcRenderer.send("request-sudo", script),
  submitPassword: (password) => ipcRenderer.send("password-submitted", password),
  onOutput: (callback) => ipcRenderer.on("script-output", (event, data) => callback(data)),
  resizeWindow: (width, height) => ipcRenderer.send("resize-window", { width, height }),
});

