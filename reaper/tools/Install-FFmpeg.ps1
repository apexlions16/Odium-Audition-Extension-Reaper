param([Parameter(Mandatory=$true)][string]$Dest)

$ErrorActionPreference = 'Stop'
$Version = '8.1.2'
$Url = 'https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-8.1.2-essentials_build.zip'
$ExpectedSha256 = 'db580001caa24ac104c8cb856cd113a87b0a443f7bdf47d8c12b1d740584a2ec'

New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$Target = Join-Path $Dest 'ffmpeg.exe'
$VersionFile = Join-Path $Dest 'ffmpeg-version.txt'

if (Test-Path -LiteralPath $Target) {
  Write-Host "FFmpeg hazır: $Target"
  exit 0
}

$SystemFfmpeg = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
if ($SystemFfmpeg) {
  Copy-Item -LiteralPath $SystemFfmpeg.Source -Destination $Target -Force
  "system:$($SystemFfmpeg.Source)" | Set-Content -LiteralPath $VersionFile -Encoding utf8
  Write-Host "Sistemdeki FFmpeg kopyalandı: $Target" -ForegroundColor Green
  exit 0
}

$TempRoot = Join-Path $env:TEMP ('odium-ffmpeg-' + [guid]::NewGuid().ToString('N'))
$Zip = "$TempRoot.zip"
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
  Write-Host "FFmpeg $Version indiriliyor..."
  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Zip
  $Actual = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($Actual -ne $ExpectedSha256) {
    throw "FFmpeg SHA-256 doğrulaması başarısız.`nBeklenen: $ExpectedSha256`nGelen: $Actual"
  }

  Expand-Archive -LiteralPath $Zip -DestinationPath $TempRoot -Force
  $Exe = Get-ChildItem -LiteralPath $TempRoot -Recurse -Filter ffmpeg.exe | Select-Object -First 1
  if (-not $Exe) { throw 'Arşivde ffmpeg.exe bulunamadı.' }
  Copy-Item -LiteralPath $Exe.FullName -Destination $Target -Force
  "gyan:$Version`nsha256:$ExpectedSha256" | Set-Content -LiteralPath $VersionFile -Encoding utf8
  Write-Host "FFmpeg kuruldu: $Target" -ForegroundColor Green
} finally {
  Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
