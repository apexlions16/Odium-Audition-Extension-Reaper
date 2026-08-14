param(
  [string]$ReaperResourcePath = "$env:APPDATA\REAPER",
  [string]$ReaperExe = '',
  [switch]$SkipFFmpeg,
  [switch]$SkipReaImGui,
  [switch]$SkipRegister
)

$ErrorActionPreference = 'Stop'
$Source = Split-Path -Parent $MyInvocation.MyCommand.Path
$Target = Join-Path $ReaperResourcePath 'Scripts\Odium Studio'
$Tools = Join-Path $Target 'tools'
$Vendor = Join-Path $Target 'vendor\reaimgui'

function Find-ReaperExe {
  param([string]$Preferred)
  $Candidates = @()
  if ($Preferred) { $Candidates += $Preferred }
  if ($env:REAPER_EXE) { $Candidates += $env:REAPER_EXE }
  $AppPath = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\reaper.exe' -ErrorAction SilentlyContinue).'(default)'
  if ($AppPath) { $Candidates += $AppPath }
  $Candidates += @(
    "$env:ProgramFiles\REAPER (x64)\reaper.exe",
    "$env:ProgramFiles\REAPER\reaper.exe",
    "${env:ProgramFiles(x86)}\REAPER\reaper.exe",
    "$env:LOCALAPPDATA\Programs\REAPER\reaper.exe"
  )
  foreach ($Candidate in $Candidates) {
    if ($Candidate -and (Test-Path -LiteralPath $Candidate)) { return (Resolve-Path -LiteralPath $Candidate).Path }
  }
  return ''
}

Write-Host 'Odium Studio - REAPER Dublaj Uzantısı kuruluyor...' -ForegroundColor Cyan
Write-Host "REAPER resource: $ReaperResourcePath"
New-Item -ItemType Directory -Force -Path $Target, (Join-Path $Target 'lib'), $Tools, $Vendor | Out-Null

$Files = @(
  'Odium_Reaper_Launcher.lua',
  'Odium_Reaper_Extension.lua',
  'Odium_Check_For_Updates.lua',
  'Register-Odium.lua',
  'Unregister-Odium.lua',
  'README.md',
  'version.json',
  'THIRD_PARTY_NOTICES.md'
)
foreach ($File in $Files) {
  $Path = Join-Path $Source $File
  if (Test-Path -LiteralPath $Path) { Copy-Item -LiteralPath $Path -Destination $Target -Force }
}
Copy-Item (Join-Path $Source 'lib\*.lua') (Join-Path $Target 'lib') -Force
Copy-Item (Join-Path $Source 'tools\*.ps1') $Tools -Force

$ResolvedReaper = Find-ReaperExe $ReaperExe

if (-not $SkipReaImGui) {
  $Fetch = Join-Path $Source 'tools\Fetch-ReaImGui.ps1'
  $Install = Join-Path $Source 'tools\Install-ReaImGui-Windows.ps1'
  & $Fetch -Dest $Vendor -Platform windows
  & $Install -ResourcePath $ReaperResourcePath -VendorPath $Vendor -ReaperExe $ResolvedReaper
}

if (-not $SkipFFmpeg) {
  & (Join-Path $Source 'tools\Install-FFmpeg.ps1') -Dest $Tools
}

Write-Host ''
Write-Host "Dosyalar kuruldu: $Target" -ForegroundColor Green

if (-not $SkipRegister) {
  if ($ResolvedReaper) {
    Write-Host "REAPER bulundu: $ResolvedReaper"
    Write-Host 'Odium Action List kaydı yapılıyor...'
    & $ResolvedReaper -nonewinst (Join-Path $Target 'Register-Odium.lua')
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "REAPER kayıt komutu $LASTEXITCODE koduyla döndü. Gerekirse Register-Odium.lua dosyasını Action List > Load ReaScript ile bir kez çalıştırın."
    }
  } else {
    Write-Warning 'REAPER executable otomatik bulunamadı. Dosyalar ve bağımlılıklar kuruldu; Register-Odium.lua dosyasını Action List > Load ReaScript ile bir kez çalıştırın.'
  }
}

Write-Host @"

Kurulum özeti
- Odium launcher: $Target\Odium_Reaper_Launcher.lua
- ReaImGui: $ReaperResourcePath\UserPlugins
- FFmpeg: $Tools\ffmpeg.exe
- Mix teslimi: Adobe Audition .sesx + medya + ZIP
- Minimum önerilen REAPER: 6.80+

Portable REAPER kullanıyorsanız -ReaperResourcePath ve gerekirse -ReaperExe parametrelerini verin.
"@
