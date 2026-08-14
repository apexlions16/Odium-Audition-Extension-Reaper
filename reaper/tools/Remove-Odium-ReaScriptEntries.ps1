param(
  [Parameter(Mandatory=$true)][string]$ResourcePath
)

$ErrorActionPreference = 'Stop'
$Kb = Join-Path $ResourcePath 'reaper-kb.ini'

if (-not (Test-Path -LiteralPath $Kb)) {
  Write-Host 'reaper-kb.ini bulunamadı; Action List temizliği gerekmiyor.'
  exit 0
}

if (Get-Process reaper -ErrorAction SilentlyContinue) {
  Write-Warning 'REAPER çalışıyor. reaper-kb.ini kullanımdayken düzenlenmedi; Odium dosyaları kaldırılmadan önce Unregister-Odium.lua çalıştırılması önerilir.'
  exit 0
}

$Backup = "$Kb.odium-backup"
Copy-Item -LiteralPath $Kb -Destination $Backup -Force

$Lines = [System.IO.File]::ReadAllLines($Kb)
$Filtered = @($Lines | Where-Object {
  $_ -notmatch 'Odium_Reaper_Launcher\.lua' -and
  $_ -notmatch 'Odium_Reaper_Extension\.lua' -and
  $_ -notmatch 'Odium_Check_For_Updates\.lua'
})

if ($Filtered.Count -eq $Lines.Count) {
  Write-Host 'Odium Action List satırı bulunamadı.'
  Remove-Item -LiteralPath $Backup -Force -ErrorAction SilentlyContinue
  exit 0
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($Kb, $Filtered, $Utf8NoBom)
Write-Host "Odium Action List satırları temizlendi. Yedek: $Backup" -ForegroundColor Green
