# Standalone platform helpers for this application. No Dream Skin cache is required.
$ErrorActionPreference='Stop'
function Enter-DreamSkinOperationLock {
  $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $gate=[Threading.Mutex]::new($false,"Local\CodexGlass.$sid.Operation")
  try{$owned=$gate.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true}
  if(-not $owned){$gate.Dispose();throw 'Another Codex Glass launch is in progress.'}
  return $gate
}
function Exit-DreamSkinOperationLock([Threading.Mutex]$Mutex){try{$Mutex.ReleaseMutex()}finally{$Mutex.Dispose()}}
function ConvertTo-DreamSkinProcessArgument([string]$Value){
  if($Value.Contains('"')){throw 'A path containing a double quote is not supported.'}
  return '"'+[regex]::Replace($Value,'(\\+)$','$1$1')+'"'
}
function Get-DreamSkinNodeRuntime {
  $candidates=@((Join-Path $PSScriptRoot 'runtime\node.exe'))
  $command=Get-Command node.exe -ErrorAction SilentlyContinue
  if($command){$candidates+=@($command.Source)}
  foreach($candidate in $candidates){
    if(-not (Test-Path -LiteralPath $candidate -PathType Leaf)){continue}
    $version=(& $candidate -p 'process.versions.node' 2>$null | Out-String).Trim()
    if($LASTEXITCODE -eq 0 -and $version -match '^(\d+)\.' -and [int]$Matches[1] -ge 22){
      $runtimePath=(& $candidate -p 'process.execPath' | Out-String).Trim()
      return [pscustomobject]@{Path=$runtimePath;Version=$version}
    }
  }
  throw 'Node.js 22 or newer is required. Download the Windows x64 release ZIP (includes Node), or install Node from https://nodejs.org/ .'
}
function Get-DreamSkinCodexInstall {
  $package=Get-AppxPackage -Name OpenAI.Codex | Where-Object {$_.PackageFamilyName -ceq 'OpenAI.Codex_2p2nqsd0c76g0'} | Sort-Object Version -Descending | Select-Object -First 1
  if(-not $package){throw 'Official Codex for Windows was not found. Install it before starting Codex Glass.'}
  $executable=Join-Path $package.InstallLocation 'app\ChatGPT.exe'
  if(-not (Test-Path -LiteralPath $executable -PathType Leaf)){throw 'The registered Codex executable is missing.'}
  return [pscustomobject]@{Executable=$executable;PackageRoot=$package.InstallLocation;PackageFullName=$package.PackageFullName;PackageFamilyName=$package.PackageFamilyName;Version=[string]$package.Version}
}
function Test-GlassPathEqual([string]$Left,[string]$Right){
  if(-not $Left -or -not $Right){return $false}
  try{return [IO.Path]::GetFullPath($Left).Equals([IO.Path]::GetFullPath($Right),[StringComparison]::OrdinalIgnoreCase)}catch{return $false}
}
function Get-GlassProcessPath($ProcessInfo){
  if($ProcessInfo.ExecutablePath){return [string]$ProcessInfo.ExecutablePath}
  try{return (Get-Process -Id $ProcessInfo.ProcessId -ErrorAction Stop).Path}catch{return $null}
}
function Get-DreamSkinCodexProcesses($Codex){
  return @(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'" -ErrorAction SilentlyContinue | Where-Object {Test-GlassPathEqual (Get-GlassProcessPath $_) $Codex.Executable})
}
function Get-DreamSkinPortListeners([int]$Port){return @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)}
function Test-GlassLoopbackAddress([string]$Address){
  $parsed=$null
  return [Net.IPAddress]::TryParse($Address,[ref]$parsed) -and [Net.IPAddress]::IsLoopback($parsed)
}
function Test-GlassBrowserSocket([string]$Url,[int]$Port){
  return $Port -ge 1024 -and $Port -le 65535 -and $Url -cmatch ('^ws://127\.0\.0\.1:'+ $Port +'/devtools/browser/[A-Za-z0-9._-]{1,200}$')
}
function Get-DreamSkinVerifiedCdpIdentity([int]$Port,$Codex){
  if($Port -lt 1024 -or $Port -gt 65535){return $null}
  $listeners=@(Get-DreamSkinPortListeners $Port)
  if(-not $listeners.Count){return $null}
  foreach($listener in $listeners){
    if(-not (Test-GlassLoopbackAddress $listener.LocalAddress)){return $null}
    $owner=Get-CimInstance Win32_Process -Filter ('ProcessId='+$listener.OwningProcess) -ErrorAction SilentlyContinue
    if(-not $owner -or -not (Test-GlassPathEqual (Get-GlassProcessPath $owner) $Codex.Executable)){return $null}
  }
  try{
    $version=Invoke-RestMethod -Uri ('http://127.0.0.1:'+$Port+'/json/version') -TimeoutSec 3
    if(-not (Test-GlassBrowserSocket $version.webSocketDebuggerUrl $Port)){return $null}
    return [pscustomobject]@{BrowserId=($version.webSocketDebuggerUrl -split '/')[-1];WebSocketDebuggerUrl=$version.webSocketDebuggerUrl}
  }catch{return $null}
}
function Select-DreamSkinPort([int]$PreferredPort=9335){
  if($PreferredPort -ge 1024 -and $PreferredPort -le 65535 -and @(Get-DreamSkinPortListeners $PreferredPort).Count -eq 0){return $PreferredPort}
  $socket=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
  try{$socket.Start();return $socket.LocalEndpoint.Port}finally{$socket.Stop()}
}
