const sudoScripts = [
  "configurar_fish.sh",
  "instalar_wine.sh",
  "instalar_steam.sh",
  "steam_fix.sh",
  "instalar_neofetch.sh",
  "instalar_fastfetch.sh",
  "instalar_yay.sh",
  "config_timeshift.sh",
  "install_node.sh"
];

function run(script) {
  document.getElementById("output").textContent = "";
  
  if (sudoScripts.includes(script)) {
    window.electronAPI.requestSudo(script);
  } else {
    window.electronAPI.runScript(script);
  }
}

window.electronAPI.onOutput((data) => {
  const output = document.getElementById("output");
  output.textContent += data + "\n";
  output.scrollTop = output.scrollHeight;
});
