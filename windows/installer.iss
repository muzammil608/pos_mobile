; Script generated for ShopFlow POS (Flutter + PocketBase)
; Inno Setup Compiler Script

#define MyAppName "ShopFlow POS"
#ifndef MyAppVersion
  #define MyAppVersion "1.2.0-beta.17"
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

; RestartManager integration is disabled because the PowerShell updater
; (update_runner.ps1, Stage 3) force-terminates pos_system.exe and
; pocketbase.exe BEFORE this installer is ever launched. InitializeSetup
; below is only a safety net for the case where Setup.exe is run standalone
; (e.g. manually, by a support tech, or via an unorchestrated re-run).
CloseApplications=no
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main Executable
Source: "{#BuildReleaseDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; All Bundle Files (DLLs, data folder, pocketbase.exe, hooks, migrations)
Source: "{#BuildReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb,*.ilk,CMakeFiles,cmake_install.cmake,pb_data"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; When running interactively with GUI, allow launching the app on finish.
; Silent updates skip this entry; update_runner.ps1 verifies the install and
; relaunches pos_system.exe after Setup exits successfully.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
begin
  { Safety net only -- under normal operation update_runner.ps1 Stage 3 has
    already force-terminated these processes before Setup.exe is ever
    launched. This guards against Setup.exe being run standalone, where
    nothing else would have released the file locks on pos_system.exe /
    pocketbase.exe.

    /F is used deliberately: a plain "taskkill" (no /F) sends WM_CLOSE, a
    Windows GUI message. pocketbase.exe is a console app with no message
    pump and silently ignores WM_CLOSE, which was the original cause of
    Setup falling back to is-*.tmp + restartreplace and stalling with
    /NORESTART. }
  Exec('taskkill.exe', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill.exe', '/F /IM pocketbase.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := True;
end;
