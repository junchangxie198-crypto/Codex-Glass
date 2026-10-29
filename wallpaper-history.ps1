# Recent images are owned copies under this controller's workspace; original files remain untouched.
$script:wallpaperHistoryDir=Join-Path $root 'assets/recent-wallpapers'
$script:wallpaperHistoryFile=Join-Path $root 'assets/recent-wallpapers.json'
function Get-WallpaperHistory {
  if(-not (Test-Path -LiteralPath $script:wallpaperHistoryFile)){return @()}
  try {
    $data=Get-Content -LiteralPath $script:wallpaperHistoryFile -Raw -Encoding UTF8|ConvertFrom-Json
    return @($data.items | Where-Object { $_.hash -match '^[a-f0-9]{64}$' -and (Test-Path -LiteralPath (Join-Path $script:wallpaperHistoryDir ($_.hash+'.image'))) } | Select-Object -First 5)
  } catch {return @()}
}
function Record-WallpaperHistory([byte[]]$Bytes,[string]$Name) {
  [IO.Directory]::CreateDirectory($script:wallpaperHistoryDir)|Out-Null
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$hash=([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
  $saved=Join-Path $script:wallpaperHistoryDir ($hash+'.image')
  if(-not (Test-Path -LiteralPath $saved)){[IO.File]::WriteAllBytes($saved,$Bytes)}
  $items=@([pscustomobject]@{hash=$hash;name=[IO.Path]::GetFileName($Name)})+@(Get-WallpaperHistory|Where-Object{$_.hash -ne $hash})
  $items=@($items|Select-Object -First 5)
  Write-ControlJson $script:wallpaperHistoryFile @{items=$items}
  return $hash
}
