; Inno Setup script for the Windows installer. Build the app first
; (flutter build windows --release), then compile with:
;   iscc /DAppVersion=1.0.0 windows\installer.iss

#define AppName "SVGA Gallery"
#define AppExe "svga_gallery.exe"
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

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
