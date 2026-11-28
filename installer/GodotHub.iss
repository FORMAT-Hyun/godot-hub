; Godot Hub installer (Inno Setup 6)
; Build: ISCC.exe installer\GodotHub.iss  (export <BuildDir>\GodotHub.exe first)
; Build output lives outside the source folder. Override with /DBuildDir=<folder>.

#define AppName "Godot Hub"
#ifndef BuildDir
  #define BuildDir "D:\고도허브 빌드"
#endif
#ifndef AppVersion
  #define AppVersion "0.2.4"
#endif

[Setup]
AppId={{6B1E2B6E-5C2A-4D7E-9F31-6A0C1B9D7E42}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=FORMAT-Hyun
AppPublisherURL=https://github.com/FORMAT-Hyun/godot-hub
AppSupportURL=https://github.com/FORMAT-Hyun/godot-hub/issues
DefaultDirName={autopf}\Godot Hub
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Install for the current user without admin rights (installing for all users is still offered)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#BuildDir}
OutputBaseFilename=GodotHub-{#AppVersion}-Setup
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\GodotHub.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\GodotHub.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\GodotHub.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\GodotHub.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\GodotHub.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
