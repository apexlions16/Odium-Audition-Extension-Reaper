; Odium Studio - REAPER Dublaj Uzantısı
; Windows per-user one-click installer, built with Inno Setup 6.

#define AppName "Odium Studio - REAPER Dublaj Uzantısı"
#define AppVersion "2.1.3"
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
DisableDirPage=no
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=Odium-REAPER-Windows-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
Uninstallable=yes
CreateUninstallRegKey=yes
SetupLogging=yes
UsePreviousAppDir=yes
CloseApplications=no
RestartApplications=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "reaimgui"; Description: "ReaImGui 0.10.0.5'i REAPER UserPlugins klasörüne kur"; GroupDescription: "Bağımlılıklar:"; Flags: checkedonce
Name: "ffmpeg"; Description: "FFmpeg'i doğrulanmış sabit paketten Odium klasörüne kur (SESX take hazırlama için önerilir)"; GroupDescription: "Bağımlılıklar:"; Flags: checkedonce
Name: "openreadme"; Description: "Kurulumdan sonra kullanım rehberini aç"; GroupDescription: "İsteğe bağlı işlemler:"; Flags: unchecked

[Files]
Source: "..\Odium_Reaper_Launcher.lua"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Odium_Reaper_Extension.lua"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Odium_Check_For_Updates.lua"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Register-Odium.lua"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Unregister-Odium.lua"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\lib\*.lua"; DestDir: "{app}\lib"; Flags: ignoreversion
Source: "..\tools\*.ps1"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "..\vendor\reaimgui\reaper_imgui-x64.dll"; DestDir: "{app}\vendor\reaimgui"; Flags: ignoreversion
Source: "..\vendor\reaimgui\reaper_imgui-x86.dll"; DestDir: "{app}\vendor\reaimgui"; Flags: ignoreversion
Source: "..\vendor\reaimgui\api\imgui.lua"; DestDir: "{app}\vendor\reaimgui\api"; Flags: ignoreversion
Source: "..\vendor\reaimgui\VERSION.txt"; DestDir: "{app}\vendor\reaimgui"; Flags: ignoreversion
Source: "..\vendor\reaimgui\licenses\*"; DestDir: "{app}\THIRD_PARTY_LICENSES"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\version.json"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\Install-ReaImGui-Windows.ps1"" -ResourcePath ""{code:GetResourcePath}"" -VendorPath ""{app}\vendor\reaimgui"" -ReaperExe ""{code:GetReaperExe}"""; StatusMsg: "ReaImGui kuruluyor..."; Flags: runhidden waituntilterminated; Tasks: reaimgui
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\Install-FFmpeg.ps1"" -Dest ""{app}\tools"""; StatusMsg: "FFmpeg indiriliyor ve doğrulanıyor..."; Flags: runhidden waituntilterminated; Tasks: ffmpeg
; Action List kaydı upgrade'lerde de HER ZAMAN onarılır. v2.1.0'da checkedonce yüzünden eski raw action kalabiliyordu.
Filename: "{code:GetReaperExe}"; Parameters: "-nonewinst ""{app}\Register-Odium.lua"""; StatusMsg: "Odium REAPER Action List kaydı onarılıyor..."; Flags: nowait; Check: HasReaperExe
Filename: "{sys}\notepad.exe"; Parameters: """{app}\README.md"""; Description: "Kullanım rehberini aç"; Flags: postinstall nowait skipifsilent; Tasks: openreadme

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\tools\Remove-Odium-ReaScriptEntries.ps1"" -ResourcePath ""{code:GetResourcePath}"""; Flags: runhidden waituntilterminated; RunOnceId: "OdiumActionCleanup"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
var
  ReaperExeCache: String;

function GetResourcePath(Param: String): String;
begin
  { Install dir is the REAPER resource Scripts/Odium Studio directory. Portable users can choose their own resource tree. }
  Result := ExtractFileDir(ExtractFileDir(ExpandConstant('{app}')));
end;

function TryReaperPath(Path: String): Boolean;
begin
  Result := (Path <> '') and FileExists(Path);
end;

function ResolveReaperExe(): String;
var
  Candidate: String;
  ResourceCandidate: String;
begin
  Result := '';

  Candidate := ExpandConstant('{param:REAPEREXE|}');
  if TryReaperPath(Candidate) then begin Result := Candidate; exit; end;

  ResourceCandidate := AddBackslash(GetResourcePath('')) + 'reaper.exe';
  if TryReaperPath(ResourceCandidate) then begin Result := ResourceCandidate; exit; end;

  if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\App Paths\reaper.exe', '', Candidate) then
    if TryReaperPath(Candidate) then begin Result := Candidate; exit; end;

  if RegQueryStringValue(HKLM64, 'Software\Microsoft\Windows\CurrentVersion\App Paths\reaper.exe', '', Candidate) then
    if TryReaperPath(Candidate) then begin Result := Candidate; exit; end;

  Candidate := ExpandConstant('{pf}\REAPER (x64)\reaper.exe');
  if TryReaperPath(Candidate) then begin Result := Candidate; exit; end;

  Candidate := ExpandConstant('{pf}\REAPER\reaper.exe');
  if TryReaperPath(Candidate) then begin Result := Candidate; exit; end;

  Candidate := ExpandConstant('{localappdata}\Programs\REAPER\reaper.exe');
  if TryReaperPath(Candidate) then begin Result := Candidate; exit; end;
end;

function GetReaperExe(Param: String): String;
begin
  if (ReaperExeCache = '') or not FileExists(ReaperExeCache) then
    ReaperExeCache := ResolveReaperExe();
  Result := ReaperExeCache;
end;

function HasReaperExe(): Boolean;
begin
  Result := GetReaperExe('') <> '';
  if not Result then
    Log('REAPER executable bulunamadı; otomatik Action List kaydı atlanacak.');
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpSelectDir then
  begin
    WizardForm.SelectDirLabel.Caption :=
      'Standart REAPER için varsayılan yolu kullanın. Portable REAPER için <resource>\Scripts\Odium Studio klasörünü seçin:';
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    Log('Odium REAPER uzantısı kuruldu: ' + ExpandConstant('{app}'));
    Log('REAPER resource path: ' + GetResourcePath(''));
    if HasReaperExe() then
      Log('REAPER executable: ' + GetReaperExe(''));
  end;
end;
