[CmdletBinding()]
param([switch]$CheckInstallation)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
. (Join-Path $project 'platform-windows.ps1')
$runtime=Get-DreamSkinNodeRuntime
$files=Get-Content -LiteralPath (Join-Path $project 'release-files.json') -Raw -Encoding UTF8|ConvertFrom-Json
foreach($relative in $files){
  $file=Join-Path $project $relative
  if(-not (Test-Path -LiteralPath $file -PathType Leaf)){throw "Missing release file: $relative"}
  if($relative.EndsWith('.ps1')){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw "PowerShell parse failure in ${relative}: $($errors[0].Message)"}
    $bytes=[IO.File]::ReadAllBytes($file)
    if($bytes.Length -gt 3 -and ($bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191)){throw "PowerShell source requires UTF-8 BOM for Windows PowerShell 5.1: $relative"}
  }
}
if(-not (Test-GlassLoopbackAddress '127.0.0.1') -or -not (Test-GlassLoopbackAddress '::1')){throw 'Loopback addresses rejected'}
foreach($address in @('0.0.0.0','::','192.168.1.2','example.com')){if(Test-GlassLoopbackAddress $address){throw "Unsafe address accepted: $address"}}
if(-not (Test-GlassBrowserSocket 'ws://127.0.0.1:9335/devtools/browser/test-123' 9335)){throw 'Valid browser identity rejected'}
foreach($url in @('ws://example.com:9335/devtools/browser/id','ws://127.0.0.1:9336/devtools/browser/id','ws://127.0.0.1:9335/devtools/page/id','ws://127.0.0.1:9335/devtools/browser/id?x=1')){if(Test-GlassBrowserSocket $url 9335){throw "Unsafe browser identity accepted: $url"}}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Drawing
foreach($xaml in @('control-window.xaml','tray-window.xaml')){
  $window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $project $xaml)))
  if(-not ($window -is [Windows.Window])){throw "Invalid WPF window: $xaml"}
  $window.Close()
}
$icon=[Drawing.Icon]::new((Join-Path $project 'assets\codex-app.ico'));$icon.Dispose()
if(-not ('CodexGlass.WindowMaterial' -as [type])){Add-Type -Path (Join-Path $project 'glass-window.cs')}
. (Join-Path $project 'session-windows.ps1')
& $runtime.Path (Join-Path $project 'build.mjs');if($LASTEXITCODE -ne 0){throw 'Payload build failed'}
Push-Location $project
try{& $runtime.Path --test control-tests.mjs wallpaper-state-tests.mjs wallpaper-payload-tests.mjs;if($LASTEXITCODE -ne 0){throw 'Node regression checks failed'}}finally{Pop-Location}
if($CheckInstallation){& (Join-Path $project 'setup.ps1') -CheckOnly}
[pscustomobject]@{status='passed';node=$runtime.Version;releaseFiles=$files.Count;windowsPowerShell=$PSVersionTable.PSVersion.ToString();installationChecked=[bool]$CheckInstallation}|ConvertTo-Json
