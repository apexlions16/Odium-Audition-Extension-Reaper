param(
  [Parameter(Mandatory=$true)][string]$ResourcePath,
  [Parameter(Mandatory=$true)][string]$VendorPath,
  [string]$ReaperExe = ''
)

$ErrorActionPreference = 'Stop'
$UserPlugins = Join-Path $ResourcePath 'UserPlugins'
$ApiPath = Join-Path $ResourcePath 'Scripts\ReaTeam Extensions\API'
New-Item -ItemType Directory -Force -Path $UserPlugins, $ApiPath | Out-Null

function Get-PeMachine([string]$Path) {
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
  $stream = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
  try {
    $reader = New-Object System.IO.BinaryReader($stream)
    $stream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
    $peOffset = $reader.ReadInt32()
    $stream.Seek($peOffset + 4, [System.IO.SeekOrigin]::Begin) | Out-Null
    return $reader.ReadUInt16()
  } finally {
    $stream.Dispose()
  }
}

$Machine = Get-PeMachine $ReaperExe
$Asset = switch ($Machine) {
  0x014c { 'reaper_imgui-x86.dll' }
  0x8664 { 'reaper_imgui-x64.dll' }
  default {
    if ([Environment]::Is64BitOperatingSystem) { 'reaper_imgui-x64.dll' }
    else { 'reaper_imgui-x86.dll' }
  }
}

$Source = Join-Path $VendorPath $Asset
if (-not (Test-Path -LiteralPath $Source)) {
  throw "ReaImGui binary bulunamadı: $Source"
}

$Target = Join-Path $UserPlugins $Asset
$NeedCopy = $true
if (Test-Path -LiteralPath $Target) {
  $SourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
  $TargetHash = (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash
  if ($SourceHash -eq $TargetHash) {
    $NeedCopy = $false
    Write-Host "ReaImGui zaten aynı sürüm: $Target"
  } elseif (Get-Process reaper -ErrorAction SilentlyContinue) {
    throw 'REAPER açıkken mevcut ReaImGui DLL güncellenemiyor. REAPER\'ı tamamen kapatıp setup dosyasını tekrar çalıştırın.'
  }
}

if ($NeedCopy) {
  Copy-Item -LiteralPath $Source -Destination $Target -Force
  Write-Host "ReaImGui kuruldu: $Target" -ForegroundColor Green
}

$ShimSource = Join-Path $VendorPath 'api\imgui.lua'
if (-not (Test-Path -LiteralPath $ShimSource)) {
  throw "ReaImGui Lua shim bulunamadı: $ShimSource"
}
$ShimTarget = Join-Path $ApiPath 'imgui.lua'
Copy-Item -LiteralPath $ShimSource -Destination $ShimTarget -Force
Write-Host "ReaImGui Lua shim kuruldu: $ShimTarget" -ForegroundColor Green

# Diğer mimariye ait binary ortak bağımlılık olabilir; otomatik silinmez.
$Other = if ($Asset -eq 'reaper_imgui-x64.dll') { 'reaper_imgui-x86.dll' } else { 'reaper_imgui-x64.dll' }
$OtherPath = Join-Path $UserPlugins $Other
if (Test-Path -LiteralPath $OtherPath) {
  Write-Host "Not: UserPlugins içinde diğer mimariye ait $Other de mevcut; ortak bağımlılık olabileceği için silinmedi."
}
