param(
  [Parameter(Mandatory=$true)][string]$Dest,
  [ValidateSet('windows','macos','linux','all')][string]$Platform = 'all'
)

$ErrorActionPreference = 'Stop'
$Version = '0.10.0.5'
$BaseUrl = "https://github.com/cfillion/reaimgui/releases/download/v$Version"
$SourceBase = "https://raw.githubusercontent.com/cfillion/reaimgui/v$Version"

$Assets = @{
  'reaper_imgui-x64.dll'        = '800b216e0937bf5bb6b08ba2767b7b974a746b3fc3b54943b4d3011da0a68f2a'
  'reaper_imgui-x86.dll'        = '6840f7c76673018d9a42590f70c4c06ce8074b7c0f126c8deb6440a24c483082'
  'reaper_imgui-arm64.dylib'    = '1f90cf004c0bbada45358609c943f601b2cb0e625ecf7739ae5df8708ab705ae'
  'reaper_imgui-x86_64.dylib'   = '2209fec3eae03f22fe94b9d2681b04e21f41c7d4587cb0d69e4eb72e39a64e65'
  'reaper_imgui-i386.dylib'     = 'dd2dcb747cbe18e390d85417905977a8a24c311bd6c4d18e03e39cb3e6f4be54'
  'reaper_imgui-x86_64.so'      = 'b967a30b356f1c689ab457f2ce393b936267e4287939ece616e10d74399e2997'
  'reaper_imgui-aarch64.so'     = '9b72753132a2ce96ae0405effaf9a8d8eeab9ab6d0f8c41ca7f62064333cdfc7'
  'reaper_imgui-i686.so'        = '4dadc055a1b8698e0d9fbf8ce3b63c39c9b5d30b0abc5734f14235d8545011d2'
  'reaper_imgui-armv7l.so'      = 'da2177ebd88f8e306e84002f045080c60beb521d43395b7ef36377ff6c35d315'
}

$Groups = @{
  windows = @('reaper_imgui-x64.dll','reaper_imgui-x86.dll')
  macos   = @('reaper_imgui-arm64.dylib','reaper_imgui-x86_64.dylib','reaper_imgui-i386.dylib')
  linux   = @('reaper_imgui-x86_64.so','reaper_imgui-aarch64.so','reaper_imgui-i686.so','reaper_imgui-armv7l.so')
}

$Wanted = if ($Platform -eq 'all') {
  @($Groups.windows + $Groups.macos + $Groups.linux)
} else {
  @($Groups[$Platform])
}

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

foreach ($Name in $Wanted) {
  $Target = Join-Path $Dest $Name
  $Expected = $Assets[$Name]
  if (Test-Path $Target) {
    $Existing = (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Existing -eq $Expected) {
      Write-Host "ReaImGui hazır: $Name"
      continue
    }
    Remove-Item -LiteralPath $Target -Force
  }

  $Url = "$BaseUrl/$Name"
  Write-Host "ReaImGui indiriliyor: $Name"
  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Target
  $Actual = (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($Actual -ne $Expected) {
    Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    throw "SHA-256 uyuşmazlığı: $Name`nBeklenen: $Expected`nGelen: $Actual"
  }
}

$LicenseDir = Join-Path $Dest 'licenses'
New-Item -ItemType Directory -Force -Path $LicenseDir | Out-Null
foreach ($License in @('COPYING','COPYING.LESSER')) {
  $LicensePath = Join-Path $LicenseDir $License
  if (-not (Test-Path -LiteralPath $LicensePath)) {
    Invoke-WebRequest -UseBasicParsing -Uri "$SourceBase/$License" -OutFile $LicensePath
  }
  if ((Get-Item -LiteralPath $LicensePath).Length -lt 1000) {
    throw "ReaImGui lisans dosyası geçersiz veya eksik: $License"
  }
}

@"
ReaImGui v$Version
Kaynak: https://github.com/cfillion/reaimgui/releases/tag/v$Version
Binary dosyalar upstream SHA-256 değerleriyle doğrulandı.
Lisans metinleri: licenses/COPYING ve licenses/COPYING.LESSER
"@ | Set-Content -LiteralPath (Join-Path $Dest 'VERSION.txt') -Encoding utf8
