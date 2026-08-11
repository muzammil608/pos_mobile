; Script generated for ShopFlow POS (Flutter + PocketBase)
; Inno Setup Compiler Script

#define MyAppName "ShopFlow POS"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "ShopFlow"
#define MyAppExeName "pos_system.exe"
#define MyAppIcon "runner\resources\app_icon.ico"
#define BuildReleaseDir "..\build\windows\x64\runner\Release"
#define OutputDir "..\build\windows\installer"

[Setup]
; Unique App ID (DO NOT CHANGE after releasing initial version to preserve update behavior)
AppId={{D3F91A2B-7889-4B52-823E-91F264C12901}
AppName={#MyAppName}
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
UsedUserAreasWarning=no
OutputDir={#OutputDir}
OutputBaseFilename=shopflow.setup

; Automatically close running app/backend during updates
CloseApplications=yes
CloseApplicationsFilter=*pos_system.exe,*pocketbase.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main Executable
Source: "{#BuildReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; All Bundle Files (DLLs, data folder, pocketbase.exe, hooks, migrations)
Source: "{#BuildReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[InstallDelete]
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\com.example\{#MyAppName}"
Type: filesandordirs; Name: "{userappdata}\com.example\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\com.example"
Type: filesandordirs; Name: "{userappdata}\com.example"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{userappdata}\com.example\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\com.example\{#MyAppName}"
Type: filesandordirs; Name: "{userappdata}\com.example"
Type: filesandordirs; Name: "{localappdata}\com.example"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  InstallId: String;
begin
  if CurStep = ssPostInstall then
  begin
    InstallId := GetDateTimeString('yyyy-mm-dd_hh-nn-ss', #0, #0);
    SaveStringToFile(ExpandConstant('{app}\install_id.txt'), InstallId, False);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DelTree(ExpandConstant('{app}'), True, True, True);
    DelTree(ExpandConstant('{userappdata}\{#MyAppName}'), True, True, True);
    DelTree(ExpandConstant('{localappdata}\{#MyAppName}'), True, True, True);
    DelTree(ExpandConstant('{userappdata}\com.example\{#MyAppName}'), True, True, True);
    DelTree(ExpandConstant('{localappdata}\com.example\{#MyAppName}'), True, True, True);
    DelTree(ExpandConstant('{userappdata}\com.example'), True, True, True);
    DelTree(ExpandConstant('{localappdata}\com.example'), True, True, True);
  end;
end;

