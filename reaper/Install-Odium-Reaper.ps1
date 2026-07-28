param(
  [string]$ReaperResourcePath = "$env:APPDATA\REAPER",
  [switch]$SkipFFmpeg
)
$ErrorActionPreference = 'Stop'
$Source = Split-Path -Parent $MyInvocation.MyCommand.Path
$Target = Join-Path $ReaperResourcePath 'Scripts\Odium Studio'
$Tools = Join-Path $Target 'tools'

Write-Host 'Odium Studio - REAPER Dublaj Uzantısı kuruluyor...' -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $Target, (Join-Path $Target 'lib'), $Tools | Out-Null
Copy-Item (Join-Path $Source 'Odium_Reaper_Extension.lua') $Target -Force
Copy-Item (Join-Path $Source 'lib\*.lua') (Join-Path $Target 'lib') -Force
Copy-Item (Join-Path $Source 'README.md') $Target -Force

if (-not $SkipFFmpeg) {
  $ffmpeg = Join-Path $Tools 'ffmpeg.exe'
  if (-not (Test-Path $ffmpeg)) {
    try {
      & (Join-Path $Source 'tools\Install-FFmpeg.ps1') -Dest $Tools
    } catch {
      Write-Warning "FFmpeg otomatik kurulamadı: $($_.Exception.Message)"
    }
  }
}

$imgui = Get-ChildItem -Path (Join-Path $ReaperResourcePath 'UserPlugins') -Filter 'reaper_imgui*.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
Write-Host ''
Write-Host "Dosyalar kuruldu: $Target" -ForegroundColor Green
if (-not $imgui) {
  Write-Warning 'ReaImGui bulunamadı. REAPER içinde Extensions > ReaPack > Browse packages > ReaImGui paketini kurun.'
}
Write-Host @"

REAPER içinde son adım:
1. Actions > Show action list
2. New action > Load ReaScript
3. Şu dosyayı seç:
   $Target\Odium_Reaper_Extension.lua
4. Action List'te "Odium Studio - REAPER Dublaj Uzantısı" çalıştır.

"@
Start-Process explorer.exe $Target
