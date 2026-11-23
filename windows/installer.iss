; Inno Setup script for the Windows installer. Build the app first
; (flutter build windows --release), then compile with:
;   iscc /DAppVersion=1.0.0 windows\installer.iss

#define AppName "SVGA Gallery"
#define AppExe "svga_gallery.exe"
#define ProgId "SVGAGallery.svga"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
; Identifies the app to Windows for upgrades and uninstall; never change it.
AppId={{9AE95828-36A8-460A-826E-17FD0E84BD6A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Zaman Sheikh
AppPublisherURL=https://github.com/zamansheikh
AppSupportURL=https://github.com/zamansheikh/svga-gallery
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#AppExe}
SetupIconFile=runner\resources\app_icon.ico
OutputDir=..\build\installer
OutputBaseFilename=SVGA-Gallery-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Installs per user without admin rights; the dialog offers "all users".
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
; Tells Explorer to pick up the .svga association without a sign-out.
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "associate"; Description: "Open .svga files with {#AppName}"; GroupDescription: "File associations:"

[Registry]
; HKA is HKCU for a per-user install and HKLM for an all-users one.
; The ProgID and the "Open with" entries are always written, so the app is
; offered for .svga files even when the user unticks the association task.
Root: HKA; Subkey: "Software\Classes\{#ProgId}"; ValueType: string; ValueName: ""; ValueData: "SVGA Animation"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#ProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExe},0"
Root: HKA; Subkey: "Software\Classes\{#ProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""
Root: HKA; Subkey: "Software\Classes\.svga\OpenWithProgids"; ValueType: string; ValueName: "{#ProgId}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}"; ValueType: string; ValueName: "FriendlyAppName"; ValueData: "{#AppName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\SupportedTypes"; ValueType: string; ValueName: ".svga"; ValueData: ""
Root: HKA; Subkey: "Software\Classes\Applications\{#AppExe}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""
; Default handler. Windows still asks once if another app already claimed
; .svga, and the user's own choice in Settings always wins.
Root: HKA; Subkey: "Software\Classes\.svga"; ValueType: string; ValueName: ""; ValueData: "{#ProgId}"; Flags: uninsdeletevalue; Tasks: associate

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
