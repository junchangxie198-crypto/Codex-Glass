$ErrorActionPreference='Stop'
try{
  & (Join-Path $PSScriptRoot 'setup.ps1') | Out-Null
  Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList ('-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $PSScriptRoot 'controller.ps1')+'"') -WindowStyle Hidden
}catch{
  Add-Type -AssemblyName System.Windows.Forms
  [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Codex Glass - startup failed')|Out-Null
  exit 1
}
