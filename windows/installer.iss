; Script generated for ShopFlow POS (Flutter + PocketBase)
; Inno Setup Compiler Script

#define MyAppName "ShopFlow POS"
#ifndef MyAppVersion
  #define MyAppVersion "1.2.0-beta.28"
#endif
#define MyAppPublisher "ShopFlow"
#define MyAppExeName "pos_system.exe"
#define MyAppIcon "runner\resources\app_icon.ico"
#define BuildReleaseDir "..\build\windows\x64\runner"
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
OutputDir={#OutputDir}
OutputBaseFilename=ShopFlow_POS_Setup_v{#MyAppVersion}

; Disable RestartManager integration since updater script terminates processes beforehand
CloseApplications=no
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main Executable
Source: "{#BuildReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion restartreplace

; All Bundle Files (DLLs, data folder, pocketbase.exe, hooks, migrations)
Source: "{#BuildReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs restartreplace; Excludes: "*.pdb,*.ilk,CMakeFiles,cmake_install.cmake,pb_data"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; When running interactively with GUI, allow launching the app on finish.
; When running silently with /VERYSILENT, the updater runner script handles relaunch via explorer.exe.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  // Force terminate any lingering instances of pos_system.exe and pocketbase.exe
  // with full administrative permissions BEFORE copying or deleting any files.
  Exec('taskkill.exe', '/F /IM pos_system.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill.exe', '/F /IM pocketbase.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(1000);
  Result := True;
end;

