; Inno Setup script for the Movie Album Sync installer.
; build-windows.ps1 runs this and passes AppVersion and SourceDir (the PyInstaller app folder).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #error SourceDir must point at the PyInstaller output folder
#endif

[Setup]
AppId={{C2190B33-3920-4A8C-9D0F-B6767AE5A589}
AppName=Movie Album Sync
AppVersion={#AppVersion}
AppVerName=Movie Album Sync {#AppVersion}
DefaultDirName={autopf}\Movie Album Sync
DefaultGroupName=Movie Album Sync
DisableProgramGroupPage=yes
DisableDirPage=yes
; Installs just for the current user, so no administrator prompt
PrivilegesRequired=lowest
OutputBaseFilename=MovieAlbumSync-{#AppVersion}-Setup
SetupIconFile=assets\icon.ico
UninstallDisplayIcon={app}\MovieAlbumSync.exe
UninstallDisplayName=Movie Album Sync
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; Clear out files from older versions before installing
Type: filesandordirs; Name: "{app}\_internal"

[Icons]
Name: "{autoprograms}\Movie Album Sync"; Filename: "{app}\MovieAlbumSync.exe"
Name: "{autodesktop}\Movie Album Sync"; Filename: "{app}\MovieAlbumSync.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\MovieAlbumSync.exe"; Description: "{cm:LaunchProgram,Movie Album Sync}"; Flags: nowait postinstall skipifsilent
; Updates started from inside the app run silently; reopen the app when they finish
Filename: "{app}\MovieAlbumSync.exe"; Flags: nowait skipifnotsilent
