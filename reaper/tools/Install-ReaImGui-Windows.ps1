param(
  [Parameter(Mandatory=$true)][string]$ResourcePath,
  [Parameter(Mandatory=$true)][string]$VendorPath,
  [string]$ReaperExe = ''
)

$ErrorActionPreference = 'Stop'
$UserPlugins = Join-Path $ResourcePath 'UserPlugins'
New-Item -ItemType Directory -Force -Path $UserPlugins | Out-Null

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
Copy-Item -LiteralPath $Source -Destination $Target -Force
Write-Host "ReaImGui kuruldu: $Target" -ForegroundColor Green

# Yanlış mimarinin Odium tarafından daha önce kurulmuş kopyasını temizle; başka isimli ReaImGui kurulumlarına dokunma.
$Other = if ($Asset -eq 'reaper_imgui-x64.dll') { 'reaper_imgui-x86.dll' } else { 'reaper_imgui-x64.dll' }
$OtherPath = Join-Path $UserPlugins $Other
if (Test-Path -LiteralPath $OtherPath) {
  Write-Host "Not: UserPlugins içinde diğer mimariye ait $Other de mevcut; ortak bağımlılık olabileceği için silinmedi."
}
