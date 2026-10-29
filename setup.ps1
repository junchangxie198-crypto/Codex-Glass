[CmdletBinding()]
param([switch]$CheckOnly,[switch]$CreateShortcuts)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'platform-windows.ps1')
$node=Get-DreamSkinNodeRuntime
$codex=Get-DreamSkinCodexInstall
foreach($file in @('controller.ps1','session-windows.ps1','glass-window.cs','control-window.xaml','tray-window.xaml','watch-session.mjs','build.mjs','assets/codex-app.ico','assets/codex-official.png')){
  if(-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))){throw "Missing application file: $file. Extract the complete ZIP first."}
}
if($CheckOnly){[pscustomobject]@{status='ready';node=$node.Version;codex=$codex.Version};return}
$probe=Join-Path $PSScriptRoot ([guid]::NewGuid().ToString('N')+'.tmp')
try{[IO.File]::WriteAllText($probe,'writable')}finally{if(Test-Path -LiteralPath $probe){Remove-Item -LiteralPath $probe}}
$utf8=[Text.UTF8Encoding]::new($false)
$statePath=Join-Path $PSScriptRoot 'control-state.json'
if(-not (Test-Path -LiteralPath $statePath)){
  [IO.File]::WriteAllText($statePath,(@{schemaVersion=1;enabled=$true;startWithWindows=$false;density=64;blur=4;closeAction='tray';wallpaperEnabled=$false;wallpaperRevision=$null}|ConvertTo-Json),$utf8)
}
$state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8|ConvertFrom-Json
if($state.enabled -isnot [bool] -or $state.startWithWindows -isnot [bool]){throw 'Saved preferences are invalid. Back up control-state.json before repairing it.'}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'control-runtime.json'),(@{node=$node.Path}|ConvertTo-Json),$utf8)
& $node.Path (Join-Path $PSScriptRoot 'build.mjs')
if($LASTEXITCODE -ne 0){throw 'Could not build the appearance payload.'}
if($CreateShortcuts){
  $shell=New-Object -ComObject WScript.Shell
  foreach($folder in @('Desktop','Programs')){
    $path=Join-Path ([Environment]::GetFolderPath($folder)) 'Codex 玻璃美化.lnk'
    $shortcut=$shell.CreateShortcut($path)
    if((Test-Path -LiteralPath $path) -and $shortcut.Arguments -notlike ('*'+$PSScriptRoot+'*')){throw "A shortcut from another installation exists: $path"}
    $shortcut.TargetPath=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $shortcut.Arguments='-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $PSScriptRoot 'start.ps1')+'"'
    $shortcut.WorkingDirectory=$PSScriptRoot;$shortcut.WindowStyle=7;$shortcut.IconLocation=(Join-Path $PSScriptRoot 'assets\codex-app.ico')+',0';$shortcut.Save()
  }
}
[pscustomobject]@{status='ready';node=$node.Version;codex=$codex.Version;shortcuts=[bool]$CreateShortcuts}
