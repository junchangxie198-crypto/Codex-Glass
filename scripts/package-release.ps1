[CmdletBinding()]
param([string]$NodePath)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$metadata=Get-Content -LiteralPath (Join-Path $project 'package.json') -Raw -Encoding UTF8|ConvertFrom-Json
$nodeInfo=Get-Content -LiteralPath (Join-Path $project 'runtime\node-provenance.json') -Raw -Encoding UTF8|ConvertFrom-Json
if(-not $NodePath){$NodePath=Join-Path $project 'runtime\node.exe'}
if(-not (Test-Path -LiteralPath $NodePath -PathType Leaf)){throw 'Place the official verified Windows x64 node.exe in runtime/, or pass -NodePath.'}
$hash=(Get-FileHash -LiteralPath $NodePath -Algorithm SHA256).Hash.ToLowerInvariant()
if($hash -cne $nodeInfo.sha256){throw 'Node runtime checksum does not match runtime/node-provenance.json.'}
$version=(& $NodePath --version | Out-String).Trim()
if($LASTEXITCODE -ne 0 -or $version -cne $nodeInfo.version){throw 'Node runtime version does not match the pinned release.'}
$list=Get-Content -LiteralPath (Join-Path $project 'release-files.json') -Raw -Encoding UTF8|ConvertFrom-Json
$dist=Join-Path $project 'dist';[IO.Directory]::CreateDirectory($dist)|Out-Null
$stage=Join-Path $dist ('stage-'+[guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($stage)|Out-Null
$name='Codex-Glass-v'+$metadata.version+'-win-x64.zip';$archive=Join-Path $dist $name
$sourceName='Codex-Glass-v'+$metadata.version+'-source.zip';$sourceArchive=Join-Path $dist $sourceName
if((Test-Path -LiteralPath $archive) -or (Test-Path -LiteralPath $sourceArchive)){throw 'Output ZIP already exists. Move the previous ZIPs aside before building replacements.'}
$records=@()
foreach($relative in $list){
  if([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)'){throw 'Invalid release file path'}
  $source=Join-Path $project $relative;$target=Join-Path $stage $relative
  [IO.Directory]::CreateDirectory((Split-Path $target -Parent))|Out-Null
  Copy-Item -LiteralPath $source -Destination $target
  $records+=@{path=($relative -replace '\\','/');sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()}
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stage,$sourceArchive,[IO.Compression.CompressionLevel]::Optimal,$false)
$sourceHash=(Get-FileHash -LiteralPath $sourceArchive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($sourceArchive+'.sha256'),($sourceHash+'  '+$sourceName+"`n"),[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $NodePath -Destination (Join-Path $stage 'runtime\node.exe')
$records+=@{path='runtime/node.exe';sha256=$hash}
$manifest=@{version=$metadata.version;platform='win-x64';node=$version;files=$records}
[IO.File]::WriteAllText((Join-Path $stage 'release-manifest.json'),($manifest|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
[IO.Compression.ZipFile]::CreateFromDirectory($stage,$archive,[IO.Compression.CompressionLevel]::Optimal,$false)
$zipHash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText(($archive+'.sha256'),($zipHash+'  '+$name+"`n"),[Text.UTF8Encoding]::new($false))
$resolvedStage=[IO.Path]::GetFullPath($stage);$distPrefix=[IO.Path]::GetFullPath($dist).TrimEnd('\')+'\'
if(-not $resolvedStage.StartsWith($distPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected staging directory'}
Remove-Item -LiteralPath $resolvedStage -Recurse -Force
[pscustomobject]@{status='packaged';archive=$archive;sourceArchive=$sourceArchive;sha256=$zipHash;bytes=(Get-Item -LiteralPath $archive).Length}|ConvertTo-Json
