param([Parameter(Mandatory=$true)][string]$Dest)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$target=Join-Path $Dest 'ffmpeg.exe'
if (Test-Path $target) { Write-Host "FFmpeg hazır: $target"; exit 0 }
$cmd=Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
if ($cmd) { Copy-Item $cmd.Source $target -Force; Write-Host "FFmpeg kopyalandı: $target"; exit 0 }
$tmp=Join-Path $env:TEMP ('odium-ffmpeg-'+[guid]::NewGuid().ToString('N'))
$zip="$tmp.zip"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
  $url='https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
  Write-Host 'FFmpeg indiriliyor...'
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip
  Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
  $exe=Get-ChildItem $tmp -Recurse -Filter ffmpeg.exe | Select-Object -First 1
  if (-not $exe) { throw 'Arşivde ffmpeg.exe bulunamadı.' }
  Copy-Item $exe.FullName $target -Force
  Write-Host "FFmpeg kuruldu: $target" -ForegroundColor Green
} finally {
  Remove-Item $zip -Force -ErrorAction SilentlyContinue
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
