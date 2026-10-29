[CmdletBinding()]
param([ValidateSet('control','enable','disable','launch','status')][string]$Action='control',[switch]$Quiet,[switch]$NoRestart)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$stateFile=Join-Path $root 'control-state.json'
$statusFile=Join-Path $root 'control-live.json'
$launchFile=Join-Path $root 'control-launch.json'
$requestDir=Join-Path $root 'control-requests'
$runtimeFile=Join-Path $root 'control-runtime.json'
$startupLink=Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex 玻璃美化.lnk'
$common=Join-Path $root 'platform-windows.ps1'
. $common
. (Join-Path $root 'session-windows.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
function Read-ControlState {
  $value=Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($value.enabled -isnot [bool] -or $value.startWithWindows -isnot [bool]) { throw '美化开关配置损坏，已停止自动操作。' }
  $densityValue=64
  if(-not [int]::TryParse([string]$value.density,[ref]$densityValue)){$densityValue=64}
  $value | Add-Member -NotePropertyName density -NotePropertyValue ([Math]::Max(30,[Math]::Min(95,$densityValue))) -Force
  $blurValue=4
  if(-not [int]::TryParse([string]$value.blur,[ref]$blurValue)){$blurValue=4}
  $value | Add-Member -NotePropertyName blur -NotePropertyValue ([Math]::Max(0,[Math]::Min(20,$blurValue))) -Force
  if ($value.closeAction -notin @('tray','exit')) { $value | Add-Member -NotePropertyName closeAction -NotePropertyValue 'tray' -Force }
  if ($value.wallpaperEnabled -isnot [bool]) { $value | Add-Member -NotePropertyName wallpaperEnabled -NotePropertyValue $true -Force }
  return $value
}
function Write-ControlJson([string]$Path,[object]$Value) {
  $temp=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
  [IO.File]::WriteAllText($temp,($Value | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
  try {
    for($attempt=0;$attempt -lt 8;$attempt++){
      try{
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temp,$Path,[System.Management.Automation.Language.NullString]::Value) } else { [IO.File]::Move($temp,$Path) }
        return
      }catch{
        if($attempt -eq 7 -or $_.Exception.GetBaseException() -isnot [IO.IOException]){throw}
        Start-Sleep -Milliseconds 25
      }
    }
  }finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue}}
}
. (Join-Path $root 'wallpaper-history.ps1')
function New-ControlShortcut([string]$Path,[string]$Arguments) {
  $shell=New-Object -ComObject WScript.Shell
  $shortcut=$shell.CreateShortcut($Path)
  $shortcut.TargetPath=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
  $shortcut.Arguments='-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$PSCommandPath+'" '+$Arguments
  $shortcut.WorkingDirectory=$root
  $shortcut.WindowStyle=7
  $shortcut.Description='开启或关闭 Codex 玻璃美化，记住开关并在登录后恢复。'
  $shortcut.IconLocation=(Join-Path $root 'assets/codex-app.ico')+',0'
  $shortcut.Save()
}
function Set-ControlStartup([bool]$Enabled) {
  if ($Enabled) { New-ControlShortcut $startupLink '-Quiet' }
  elseif (Test-Path -LiteralPath $startupLink) { Remove-Item -LiteralPath $startupLink }
}
function Get-ControlCodexSession {
  $codex=Get-DreamSkinCodexInstall
  $primary=@(Get-DreamSkinCodexProcesses -Codex $codex | Where-Object { $_.CommandLine -notmatch '--type=' })
  foreach ($item in $primary) {
    $match=[regex]::Match($item.CommandLine,'--remote-debugging-port=(\d+)')
    if ($match.Success) {
      $port=[int]$match.Groups[1].Value
      $identity=Get-GlassVerifiedCdpIdentity -Port $port -Codex $codex
      if ($null -ne $identity) { return [pscustomobject]@{Codex=$codex;Primary=$primary;Port=$port;Identity=$identity} }
    }
  }
  return [pscustomobject]@{Codex=$codex;Primary=$primary;Port=0;Identity=$null}
}
if ($Action -eq 'status') {
  [pscustomobject]@{saved=(Read-ControlState);live=if(Test-Path -LiteralPath $statusFile){Get-Content -LiteralPath $statusFile -Raw -Encoding UTF8 | ConvertFrom-Json}else{$null};startup=(Test-Path -LiteralPath $startupLink)} | ConvertTo-Json -Depth 6
  exit
}
if ($Action -eq 'launch') {
  $lock=$null
  try {
    $lock=Enter-DreamSkinOperationLock
    $session=Get-ControlCodexSession
    if ($null -eq $session.Identity) {
      if ($session.Primary.Count -gt 0) {
        Write-ControlJson $launchFile @{status='waiting';message="接口未连接：当前 Codex 无法连接。`n请退出 Codex，再点击下方按钮重新启动。"}
        exit
      }
      $preferred=9335
      $savedControl=Read-ControlState
      $savedPort=0
      $hasSavedPort=[int]::TryParse([string]$savedControl.lastPort,[ref]$savedPort) -and $savedPort -ge 1024 -and $savedPort -le 65535
      if($hasSavedPort){$preferred=$savedPort}
      $port=Select-DreamSkinPort -PreferredPort $preferred
      $activatedPid=Start-GlassPackagedCodex -Port $port -Codex $session.Codex
      $deadline=(Get-Date).AddSeconds(35)
      do {
        $verified=Get-GlassVerifiedCdpIdentity -Port $port -Codex $session.Codex
        if($null -ne $verified){break}
        Start-Sleep -Milliseconds 350
      }while((Get-Date) -lt $deadline)
      if($null -eq $verified){throw 'Codex 已激活，但尚未通过包身份和本机连接检查。请稍后重试；当前壁纸配置保持不变。'}
    }
    Write-ControlJson $launchFile @{status='started';message='已通过官方包身份与本机连接检查，等待窗口准备好后自动应用。'}
  } catch { Write-ControlJson $launchFile @{status='error';message=$_.Exception.Message} }
  finally { if ($null -ne $lock) { Exit-DreamSkinOperationLock $lock } }
  exit
}
[IO.Directory]::CreateDirectory($requestDir) | Out-Null
if ($Action -in @('enable','disable') -or -not $Quiet) {
  Write-ControlJson (Join-Path $requestDir ([guid]::NewGuid().ToString('N')+'.json')) @{action=if($Action -eq 'control'){'open'}else{$Action}}
}
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$mutex=[Threading.Mutex]::new($false,"Local\CodexGlassController.$sid")
$acquired=$false
try { $acquired=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $acquired=$true }
if (-not $acquired) { $mutex.Dispose();exit }
$worker=$null;$launcher=$null;$timer=$null;$tray=$null;$densitySaveTimer=$null;$uiIcon=$null
try {
  $runtime=Get-Content -LiteralPath $runtimeFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not (Test-Path -LiteralPath $runtime.node)) { throw 'Node 运行环境位置已变化，请重新运行 install-control.ps1。' }
  # Use the installed runtime even when Codex's extra PATH is absent at Windows login.
  $env:PATH=(Split-Path $runtime.node -Parent)+';'+$env:PATH
  $settings=Read-ControlState
  Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
  if(-not ('CodexGlass.WindowMaterial' -as [type])){Add-Type -Path (Join-Path $root 'glass-window.cs')}
  [void][CodexGlass.WindowMaterial]::SetAppIdentity()
  $form=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $root 'control-window.xaml')))
  $form.MaxHeight=[Math]::Max(480,[Windows.SystemParameters]::WorkArea.Height-24)
  $label=$form.FindName('StatusLabel');$statusDot=$form.FindName('StatusDot')
  $toggle=$form.FindName('ToggleBeauty')
  $densityLabel=$form.FindName('DensityLabel');$density=$form.FindName('GlassDensitySlider')
  $blurLabel=$form.FindName('BlurLabel');$blur=$form.FindName('GlassBlurSlider')
  $resetDensity=$form.FindName('ResetDensity');$auto=$form.FindName('AutoStartSwitch')
  $wallpaperSwitch=$form.FindName('WallpaperSwitch');$wallpaperSwitch.IsChecked=[bool]$settings.wallpaperEnabled
  $closeTray=$form.FindName('CloseToTray');$closeExit=$form.FindName('CloseExit');$closeHint=$form.FindName('CloseHint')
  $closeTray.IsChecked=($settings.closeAction -eq 'tray');$closeExit.IsChecked=($settings.closeAction -eq 'exit')
  $closeHint.Text=if($settings.closeAction -eq 'tray'){'关闭面板后，仍可从托盘调节。'}else{'退出后当前效果保留至 Codex 窗口关闭。'}
  $density.Value=[int]$settings.density;$densityLabel.Text=([string]$settings.density+'%');$auto.IsChecked=[bool]$settings.startWithWindows
  $blur.Value=[int]$settings.blur;$blurLabel.Text=([string]$settings.blur+' px')
  $image=[Windows.Media.Imaging.BitmapFrame]::Create([uri](Join-Path $root 'assets/codex-official.png'),[Windows.Media.Imaging.BitmapCreateOptions]::None,[Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
  $form.FindName('BrandIcon').Source=$image;$form.Icon=$image
  $form.Add_SourceInitialized({
    $handle=[Windows.Interop.WindowInteropHelper]::new($form).Handle
    $source=[Windows.Interop.HwndSource]::FromHwnd($handle)
    $source.CompositionTarget.BackgroundColor=[Windows.Media.Colors]::Transparent
    $script:materialResult=[CodexGlass.WindowMaterial]::Apply($handle,$script:isDark)
  })
  $form.FindName('MinimizeButton').Add_Click({$form.WindowState='Minimized'})
  $form.FindName('CloseButton').Add_Click({$form.Close()})
  $menu=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $root 'tray-window.xaml')))
  $menu.Add_SourceInitialized({$handle=[Windows.Interop.WindowInteropHelper]::new($menu).Handle;[Windows.Interop.HwndSource]::FromHwnd($handle).CompositionTarget.BackgroundColor=[Windows.Media.Colors]::Transparent;[void][CodexGlass.WindowMaterial]::Apply($handle,$script:isDark)})
  $menu.Add_Deactivated({$menu.Hide()})
  $menu.Add_Closing({param($sender,$e) if(-not $script:exiting){$e.Cancel=$true;$menu.Hide()}})
  $tray=New-Object Windows.Forms.NotifyIcon
  $uiIcon=[Drawing.Icon]::new((Join-Path $root 'assets/codex-app.ico'))
  $tray.Icon=$uiIcon;$tray.Text='Codex 玻璃美化';$tray.Visible=$true
  $script:isDark=$false;$script:lastTheme=''
  function Update-ControlTheme {
    $dark=((Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction SilentlyContinue).AppsUseLightTheme -eq 0)
    if ($script:lastTheme -eq [string]$dark) { return }
    $script:lastTheme=[string]$dark;$script:isDark=$dark
    $colors=if($dark){@{Ink='#F2F5FB';Secondary='#B7C5D7';Action='#83BBFF';Panel='#6637465C';Edge='#55DCEBFF';Base='#C0151F30';Rail='#667C91A9';ScrollThumb='#A28DA1B9';ConnectionAlert='#FFD275';ConnectionReady='#54DC9D'}}else{@{Ink='#172033';Secondary='#56647A';Action='#006DDE';Panel='#A6FFFFFF';Edge='#CFFFFFFF';Base='#AAF6FBFF';Rail='#D4DFEB';ScrollThumb='#A26C8098';ConnectionAlert='#8C5100';ConnectionReady='#087C49'}}
    foreach($window in @($form,$menu)) {
      foreach($key in $colors.Keys){$window.Resources[$key]=[Windows.Media.BrushConverter]::new().ConvertFromString($colors[$key])}
      $handle=[Windows.Interop.WindowInteropHelper]::new($window).Handle
      if($handle -ne [IntPtr]::Zero){[void][CodexGlass.WindowMaterial]::Apply($handle,$dark)}
    }
  }
  Update-ControlTheme
  function Set-ConnectionVisual([bool]$Connected) {
    $statusDot.SetResourceReference([Windows.Shapes.Shape]::FillProperty,$(if($Connected){'ConnectionReady'}else{'ConnectionAlert'}))
    $label.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,$(if($Connected){'Secondary'}else{'ConnectionAlert'}))
    $label.FontWeight=if($Connected){[Windows.FontWeights]::Normal}else{[Windows.FontWeights]::SemiBold}
  }
  function Show-Control { $menu.Hide();$form.Show();$form.WindowState='Normal';$form.Activate() | Out-Null }
  function Update-BeautyButton {
    $caption=if($script:settings.enabled){'关闭美化'}else{'开启美化'}
    $toggle.Content=$caption;[Windows.Automation.AutomationProperties]::SetName($toggle,$caption)
    $toggle.ToolTip=if($script:settings.enabled){'关闭玻璃外观'}else{'为已运行的 Codex 启用玻璃外观'}
    $menu.FindName('TrayToggle').Content=$caption
  }
  function Set-ControlEnabled([bool]$Enabled) {
    $script:settings.enabled=$Enabled
    Write-ControlJson $stateFile $script:settings
    Update-BeautyButton
    $label.Text=if($Enabled){'已记住开启状态，正在准备…'}else{'已记住关闭状态，正在移除玻璃效果…'}
  }
  function Toggle-ControlBeauty { Set-ControlEnabled (-not $script:settings.enabled) }
  function Connect-ControlOnOpen {
    if ($null -ne $script:launcher -and -not $script:launcher.HasExited) { return }
    if(Test-Path -LiteralPath $launchFile){Remove-Item -LiteralPath $launchFile}
    $args='-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$PSCommandPath+'" -Action launch -NoRestart'
    $script:launcher=Start-Process -FilePath (Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList $args -WindowStyle Hidden -PassThru
  }
  Update-BeautyButton
  $toggle.Add_Click({Toggle-ControlBeauty})
  $form.FindName('LaunchCodex').Add_Click({Connect-ControlOnOpen})
  $saveWallpaper={
    if($wallpaperSwitch.IsChecked -and -not (Test-Path -LiteralPath (Join-Path $root 'assets/user-wallpaper.jpg'))){
      $wallpaperSwitch.IsChecked=$false
      [Windows.MessageBox]::Show($form,'请先选择一张背景图片。','背景图片',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Information)|Out-Null
      return
    }
    try{$script:settings.wallpaperEnabled=[bool]$wallpaperSwitch.IsChecked;Write-ControlJson $stateFile $script:settings}catch{$label.Text='背景设置未能保存：'+$_.Exception.Message}
  }
  $wallpaperSwitch.Add_Checked($saveWallpaper);$wallpaperSwitch.Add_Unchecked($saveWallpaper)
  function Set-WallpaperFromPath([string]$Path,[string]$DisplayName) {
    $destination=Join-Path $root 'assets/user-wallpaper.jpg';$backup=$null;$temp=$null;$replaced=$false;$committed=$false;$oldRevision=$script:settings.wallpaperRevision
    try {
      $file=Get-Item -LiteralPath $Path
      if($file.Length -gt 16777216 -or $file.Length -lt 8){throw '请选择不超过 16 MB 的 JPEG 或 PNG 图片。'}
      $bytes=[IO.File]::ReadAllBytes($file.FullName)
      $jpeg=$bytes[0] -eq 255 -and $bytes[1] -eq 216 -and $bytes[2] -eq 255
      $png=$bytes[0] -eq 137 -and $bytes[1] -eq 80 -and $bytes[2] -eq 78 -and $bytes[3] -eq 71 -and $bytes[4] -eq 13 -and $bytes[5] -eq 10 -and $bytes[6] -eq 26 -and $bytes[7] -eq 10
      if(-not ($jpeg -or $png)){throw '请选择有效的 JPEG 或 PNG 图片。'}
      $stream=[IO.MemoryStream]::new($bytes,$false)
      try{$frame=[Windows.Media.Imaging.BitmapFrame]::Create($stream,[Windows.Media.Imaging.BitmapCreateOptions]::DelayCreation,[Windows.Media.Imaging.BitmapCacheOption]::OnDemand);if($frame.PixelWidth -lt 1 -or $frame.PixelHeight -lt 1 -or $frame.PixelWidth -gt 10000 -or $frame.PixelHeight -gt 10000){throw '图片尺寸须在 1 至 10000 像素之间。'}}finally{$stream.Dispose()}
      if(Test-Path -LiteralPath $destination){$backup=[IO.File]::ReadAllBytes($destination)}
      $temp=$destination+'.'+[guid]::NewGuid().ToString('N')+'.tmp';[IO.File]::WriteAllBytes($temp,$bytes)
      if(Test-Path -LiteralPath $destination){[IO.File]::Replace($temp,$destination,[System.Management.Automation.Language.NullString]::Value)}else{[IO.File]::Move($temp,$destination)};$temp=$null;$replaced=$true
      $revision=Record-WallpaperHistory $bytes $DisplayName
      $script:settings | Add-Member -NotePropertyName wallpaperRevision -NotePropertyValue $revision -Force
      if(-not $wallpaperSwitch.IsChecked){$wallpaperSwitch.IsChecked=$true}
      Write-ControlJson $stateFile $script:settings;$committed=$true
      $label.Text='背景图片已保存，正在应用…'
      Update-WallpaperHistoryUI
      Update-Control
    }catch{if($replaced -and -not $committed){if($null -ne $backup){[IO.File]::WriteAllBytes($destination,$backup)}elseif(Test-Path -LiteralPath $destination){Remove-Item -LiteralPath $destination};$script:settings | Add-Member -NotePropertyName wallpaperRevision -NotePropertyValue $oldRevision -Force};[Windows.MessageBox]::Show($form,$_.Exception.Message,'背景图片',[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Warning)|Out-Null}
    finally{if($temp -and (Test-Path -LiteralPath $temp)){Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue}}
  }
  $script:wallpaperPreviewCache=@{}
  function Update-WallpaperHistoryUI {
    $grid=$form.FindName('RecentWallpaperGrid');$section=$form.FindName('RecentWallpaperSection');$grid.Children.Clear()
    $items=@(Get-WallpaperHistory);$section.Visibility=if($items.Count){'Visible'}else{'Collapsed'}
    $recentHashes=@($items|ForEach-Object{$_.hash});foreach($key in @($script:wallpaperPreviewCache.Keys)){if($key -notin $recentHashes){$script:wallpaperPreviewCache.Remove($key)}}
    $current=Join-Path $root 'assets/user-wallpaper.jpg'
    $currentHash=''
    if(Test-Path -LiteralPath $current){$sha=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::OpenRead($current);try{$currentHash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$stream.Dispose();$sha.Dispose()}}
    foreach($item in $items){
      $path=Join-Path $script:wallpaperHistoryDir ($item.hash+'.image')
      try {
        $bitmap=$script:wallpaperPreviewCache[$item.hash]
        if($null -eq $bitmap){$bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$bitmap.DecodePixelWidth=192;$bitmap.UriSource=[uri]$path;$bitmap.EndInit();$bitmap.Freeze();$script:wallpaperPreviewCache[$item.hash]=$bitmap}
        $brush=[Windows.Media.ImageBrush]::new($bitmap);$brush.Stretch='UniformToFill'
        $tile=[Windows.Controls.Border]::new();$tile.Width=68;$tile.Height=54;$tile.CornerRadius=[Windows.CornerRadius]::new(7);$tile.Background=$brush
        $tile.BorderThickness=[Windows.Thickness]::new($(if($item.hash -eq $currentHash){2}else{1}));$tile.BorderBrush=if($item.hash -eq $currentHash){[Windows.Media.BrushConverter]::new().ConvertFromString('#4DA0FF')}else{$form.Resources['Edge']}
        $button=[Windows.Controls.Button]::new();$button.Style=$form.Resources['SoftButton'];$button.Padding=[Windows.Thickness]::new(0);$button.BorderThickness=[Windows.Thickness]::new(0);$button.Background=[Windows.Media.Brushes]::Transparent;$button.Margin=[Windows.Thickness]::new(0,0,6,0);$button.Content=$tile;$button.Tag=$path;$button.ToolTip=$item.name
        [Windows.Automation.AutomationProperties]::SetName($button,('切换背景：'+$item.name));[Windows.Automation.AutomationProperties]::SetAutomationId($button,('RecentWallpaper_'+$item.hash.Substring(0,12)))
        $button.Add_Click({param($sender,$eventArgs) $entry=@(Get-WallpaperHistory|Where-Object{(Join-Path $script:wallpaperHistoryDir ($_.hash+'.image')) -eq $sender.Tag})|Select-Object -First 1;if($entry){Set-WallpaperFromPath $sender.Tag $entry.name}})
        [void]$grid.Children.Add($button)
      }catch{continue}
    }
  }
  if(@(Get-WallpaperHistory).Count -eq 0 -and (Test-Path -LiteralPath (Join-Path $root 'assets/user-wallpaper.jpg'))){try{[void](Record-WallpaperHistory ([IO.File]::ReadAllBytes((Join-Path $root 'assets/user-wallpaper.jpg'))) '当前背景')}catch{}}
  Update-WallpaperHistoryUI
  $form.FindName('ChooseWallpaper').Add_Click({
    $picker=New-Object Microsoft.Win32.OpenFileDialog
    $picker.Title='选择 Codex 背景图片';$picker.Filter='图片文件 (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png';$picker.CheckFileExists=$true;$picker.Multiselect=$false
    if($picker.ShowDialog($form) -eq $true){Set-WallpaperFromPath $picker.FileName ([IO.Path]::GetFileName($picker.FileName))}
  })
  $menu.FindName('TrayToggle').Add_Click({$menu.Hide();Toggle-ControlBeauty})
  $menu.FindName('TrayShow').Add_Click({Show-Control})
  function Show-TrayMenu {
    Update-ControlTheme
    $point=[Windows.Forms.Cursor]::Position;$screen=[Windows.Forms.Screen]::FromPoint($point).WorkingArea
    $source=[Windows.PresentationSource]::FromVisual($form)
    $scaleX=1.0;$scaleY=1.0;if($source){$scaleX=$source.CompositionTarget.TransformFromDevice.M11;$scaleY=$source.CompositionTarget.TransformFromDevice.M22}
    $menu.Left=[Math]::Max($screen.Left*$scaleX,[Math]::Min(($screen.Right*$scaleX)-$menu.Width,$point.X*$scaleX-$menu.Width))
    $menu.Top=[Math]::Max($screen.Top*$scaleY,[Math]::Min(($screen.Bottom*$scaleY)-200,$point.Y*$scaleY-200))
    $menu.Show();$menu.Activate() | Out-Null
  }
  # Let the Windows notification overflow finish closing before activating our menu.
  $menuOpenTimer=New-Object Windows.Threading.DispatcherTimer
  $menuOpenTimer.Interval=[TimeSpan]::FromMilliseconds(200)
  $menuOpenTimer.Add_Tick({$menuOpenTimer.Stop();Show-TrayMenu})
  $tray.Add_MouseUp({param($sender,$e) if($e.Button -eq [Windows.Forms.MouseButtons]::Right){$menuOpenTimer.Stop();$menuOpenTimer.Start()}})
  $tray.Add_DoubleClick({Show-Control})
  $script:densityDirty=$false
  function Save-ControlDensity {
    if(-not $script:densityDirty){return}
    try{Write-ControlJson $stateFile $script:settings;$script:densityDirty=$false}catch{$label.Text='浓度未能保存：'+$_.Exception.Message}
  }
  $densitySaveTimer=New-Object Windows.Threading.DispatcherTimer
  $densitySaveTimer.Interval=[TimeSpan]::FromMilliseconds(100)
  $densitySaveTimer.Add_Tick({$densitySaveTimer.Stop();Save-ControlDensity})
  $density.Add_ValueChanged({$densityLabel.Text=([string][int]$density.Value+'%');$script:settings.density=[int]$density.Value;$script:densityDirty=$true;if(-not $densitySaveTimer.IsEnabled){$densitySaveTimer.Start()}})
  $blur.Add_ValueChanged({$blurLabel.Text=([string][int]$blur.Value+' px');$script:settings.blur=[int]$blur.Value;$script:densityDirty=$true;if(-not $densitySaveTimer.IsEnabled){$densitySaveTimer.Start()}})
  $resetDensity.Add_Click({$density.Value=64;$blur.Value=4})
  $script:exiting=$false
  function Exit-Control {Save-ControlDensity;$script:exiting=$true;$menu.Close();$form.Close();$application.Shutdown()}
  $menu.FindName('TrayExit').Add_Click({Exit-Control})
  $form.Add_Closing({param($sender,$eventArgs) Save-ControlDensity;if(-not $script:exiting){if($script:settings.closeAction -eq 'tray'){$eventArgs.Cancel=$true;$form.Hide()}else{$script:exiting=$true;$menu.Close();$application.Shutdown()}}})
  $saveClose={
    if($closeTray.IsChecked){$script:settings.closeAction='tray';$closeHint.Text='关闭面板后，仍可从托盘调节。'}
    elseif($closeExit.IsChecked){$script:settings.closeAction='exit';$closeHint.Text='退出后当前效果保留至 Codex 窗口关闭。'}else{return}
    try{Write-ControlJson $stateFile $script:settings}catch{$label.Text='关闭选项未能保存：'+$_.Exception.Message}
  }
  $closeTray.Add_Checked($saveClose);$closeExit.Add_Checked($saveClose)
  $saveStartup={try{Set-ControlStartup ([bool]$auto.IsChecked);$script:settings.startWithWindows=[bool]$auto.IsChecked;Write-ControlJson $stateFile $script:settings}catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message,'Codex 玻璃美化') | Out-Null}}
  $auto.Add_Checked($saveStartup);$auto.Add_Unchecked($saveStartup)
  $script:lastDiscovery=[datetime]::MinValue
  $script:lastObserved=''
  function Update-Control {
    try {
      Update-ControlTheme
      foreach ($request in @(Get-ChildItem -LiteralPath $requestDir -Filter '*.json' | Sort-Object LastWriteTime)) {
        $value=Get-Content -LiteralPath $request.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        Remove-Item -LiteralPath $request.FullName
        switch ($value.action) {'open'{Show-Control;$script:lastDiscovery=[datetime]::MinValue};'show'{Show-Control};'show-menu'{Show-TrayMenu};'enable'{Set-ControlEnabled $true};'disable'{Set-ControlEnabled $false}}
      }
      if ($null -ne $script:worker -and $script:worker.HasExited) { $script:worker.Dispose();$script:worker=$null }
      if ($null -eq $script:worker -and ((Get-Date)-$script:lastDiscovery).TotalSeconds -ge 8) {
        $script:lastDiscovery=Get-Date
        $session=Get-ControlCodexSession
        if ($null -ne $session.Identity) {
          if($script:settings.lastPort -ne $session.Port){
            $script:settings | Add-Member -NotePropertyName lastPort -NotePropertyValue $session.Port -Force
            Write-ControlJson $stateFile $script:settings
          }
          & $runtime.node (Join-Path $root 'build.mjs')
          if ($LASTEXITCODE -ne 0) { throw '美化配置编译失败。' }
          $args=@((Join-Path $root 'watch-session.mjs'),[string]$session.Port,$session.Identity.BrowserId,$stateFile,$statusFile) | ForEach-Object { ConvertTo-DreamSkinProcessArgument ([string]$_) }
          $script:worker=Start-Process -FilePath $runtime.node -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $root 'control-worker-error.log')
        } else {
          $message=if($session.Primary.Count -gt 0){"接口未连接：当前 Codex 无法连接。`n请退出 Codex，再点击下方按钮重新启动。"}elseif($null -ne $script:launcher -and -not $script:launcher.HasExited){"接口未连接`n正在启动 Codex，请稍候…"}else{"接口未连接：Codex 未运行。`n点击下方按钮启动支持美化的 Codex。"}
          $label.Text=$message
          Set-ConnectionVisual $false
          Write-ControlJson $statusFile @{status=if($settings.enabled){'needs-launch'}else{'off'};message=$message;updatedAt=(Get-Date).ToString('o')}
        }
      }
      if ($null -ne $script:worker -and (Test-Path -LiteralPath $statusFile)) {
        try {
          $live=Get-Content -LiteralPath $statusFile -Raw -Encoding UTF8 | ConvertFrom-Json
          $label.Text=switch($live.status){'on'{"美化接口已连接`n玻璃美化已开启。"};'off'{"美化接口已连接`n玻璃美化已关闭。"};default{"美化接口连接中`n正在等待 Codex 窗口就绪。"}}
          Set-ConnectionVisual ($live.status -in @('on','off'))
          $tray.Text=if($live.status -eq 'on'){'Codex 玻璃美化 · 已开启'}elseif($live.status -eq 'off'){'Codex 玻璃美化 · 已关闭'}else{'Codex 玻璃美化 · 等待连接'}
        } catch {} # Atomic status refresh may briefly race file access.
      }
      if ($null -ne $script:launcher -and $script:launcher.HasExited) {
        $script:launcher.Dispose();$script:launcher=$null;$script:lastDiscovery=[datetime]::MinValue
        if(Test-Path -LiteralPath $launchFile){$launch=Get-Content -LiteralPath $launchFile -Raw -Encoding UTF8|ConvertFrom-Json;if($launch.status -in @('waiting','error')){$label.Text=$launch.message;Set-ConnectionVisual $false}}
      }
    } catch { $label.Text='未能应用：'+$_.Exception.Message;Set-ConnectionVisual $false }
  }
  $application=New-Object Windows.Application
  $application.ShutdownMode=[Windows.ShutdownMode]::OnExplicitShutdown
  $timer=New-Object Windows.Threading.DispatcherTimer
  $timer.Interval=[TimeSpan]::FromMilliseconds(1500);$timer.Add_Tick({Update-Control});$timer.Start()
  # Opening the controller never closes or starts Codex without an explicit button action.
  Update-Control
  [void]$application.Run()
} catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Codex 玻璃美化') | Out-Null;exit 1 }
finally {
  if($null -ne $densitySaveTimer){$densitySaveTimer.Stop()}
  if($null -ne $timer){$timer.Stop()}
  if($null -ne $worker -and -not $worker.HasExited){$worker.Kill();$worker.WaitForExit(3000) | Out-Null}
  if($null -ne $tray){$tray.Visible=$false;$tray.Dispose()}
  if($null -ne $uiIcon){$uiIcon.Dispose()}
  $mutex.ReleaseMutex();$mutex.Dispose()
}
