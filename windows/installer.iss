; Script generated for ShopFlow POS (Flutter + PocketBase)
; Inno Setup Compiler Script

#define MyAppName "ShopFlow POS"
#ifndef MyAppVersion
  #define MyAppVersion "1.2.0-beta.2"
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
; ============================================================================
; THIS IS THE ONLY RELAUNCH MECHANISM FOR THE APP AFTER AN UPDATE.
;
; update_service.dart's PowerShell updater (update_runner.ps1) does NOT
; relaunch the app itself anymore -- an earlier version of that script had
; its own relaunch step (via explorer.exe) running *in addition* to this
; [Run] entry, which caused two instances of pos_system.exe to open after
; every silent update. That relaunch step has been removed from the
; PowerShell script; this entry is now the single source of truth.
;
; "skipifsilent" is deliberately absent: the updater always installs with
; /VERYSILENT, and skipifsilent unconditionally skips this entry in silent
; mode -- that was the original reason the app never came back after an
; update.
;
; "runasoriginaluser" hands the relaunched process back to the normal user's
; token instead of inheriting the installer's admin elevation. This works
; reliably because the PowerShell updater keeps a live, non-elevated parent
; process running for the entire install (it launches Setup.exe with
; Start-Process -Verb RunAs and then polls for it to exit, rather than
; exiting itself immediately) -- so runasoriginaluser always has a valid,
; live parent token to query. The previous failure (silent relaunch failure)
; was caused by that parent process dying within ~10ms of launching Setup.exe.
; ============================================================================
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall runasoriginaluser

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
