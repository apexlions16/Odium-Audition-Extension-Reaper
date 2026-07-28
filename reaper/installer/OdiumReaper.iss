; Odium Studio - REAPER Dublaj Uzantısı
; Windows per-user installer, built with Inno Setup 6.

#define AppName "Odium Studio - REAPER Dublaj Uzantısı"
#define AppVersion "2.0.0"
#define AppPublisher "Odium Studio"
#define AppId "{{C1E0579A-6A8B-4E88-A1B0-0D2F3BC56A15}"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}.0
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName}
DefaultDirName={userappdata}\REAPER\Scripts\Odium Studio
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=Odium-REAPER-v{#AppVersion}-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
Uninstallable=yes
CreateUninstallRegKey=yes
SetupLogging=yes

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "ffmpeg"; Description: "FFmpeg'i otomatik indir ve uzantı klasörüne kur"; GroupDescription: "İsteğe bağlı bileşenler:"; Flags: checkedonce
Name: "openreadme"; Description: "Kurulumdan sonra kullanım rehberini aç"; GroupDescription: "İsteğe bağlı işlemler:"; Flags: checkedonce

[Files]
Source: "..\Odium_Reaper_Extension.lua"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\lib\*.lua"; DestDir: "{app}\lib"; Flags: ignoreversion
Source: "..\tools\Install-FFmpeg.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\version.json"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\Install-FFmpeg.ps1"" -Dest ""{app}\tools"""; StatusMsg: "FFmpeg indiriliyor ve kuruluyor..."; Flags: runhidden waituntilterminated; Tasks: ffmpeg
Filename: "{sys}\notepad.exe"; Parameters: """{app}\README.md"""; Description: "Kullanım rehberini aç"; Flags: postinstall nowait skipifsilent; Tasks: openreadme

[UninstallDelete]
Type: filesandordirs; Name: "{app}\tools"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    Log('Odium REAPER uzantısı kuruldu: ' + ExpandConstant('{app}'));
  end;
end;
