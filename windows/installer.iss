; ShopFlow POS Windows installer

#define MyAppName "ShopFlow POS"
#ifndef MyAppVersion
  #define MyAppVersion "1.2.0-beta.15"
#endif
#define MyAppPublisher "ShopFlow"
#define MyAppExeName "pos_system.exe"
#define MyAppIcon "runner\resources\app_icon.ico"
#define BuildReleaseDir "..\build\windows\x64\runner"
#define OutputDir "..\build\windows\installer"

[Setup]
AppId={{D3F91A2B-7889-4B52-823E-91F264C12901}
AppName=ShopFlow POS
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile={#MyAppIcon}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
OutputDir={#OutputDir}
OutputBaseFilename=ShopFlow_POS_Setup_v{#MyAppVersion}
CloseApplications=no
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb,*.ilk,CMakeFiles,cmake_install.cmake,pb_data,pocketbase.exe,pb_hooks\*,pb_migrations\*"
Source: "{#BuildReleaseDir}\pocketbase.exe"; DestDir: "{code:GetBackendDir}"; Flags: ignoreversion
Source: "{#BuildReleaseDir}\pb_hooks\*"; DestDir: "{code:GetBackendDir}\pb_hooks"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BuildReleaseDir}\pb_migrations\*"; DestDir: "{code:GetBackendDir}\pb_migrations"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{code:GetBackendDir}"

[Code]
function GetBackendDir(Param: String): String;
begin
  Result := ExpandConstant('{autopf32}') + '\ShopFlow POS Backend';
end;

function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  Exec('taskkill.exe', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill.exe', '/F /IM pocketbase.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;
