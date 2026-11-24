; Godot Hub 설치 프로그램 (Inno Setup 6)
; 빌드: ISCC.exe installer\GodotHub.iss  (먼저 build\GodotHub.exe 를 내보내야 함)

#define AppName "Godot Hub"
#ifndef AppVersion
  #define AppVersion "0.2.0"
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
; 관리자 권한 없이 내 계정에만 설치 (원하면 모든 사용자 설치도 고를 수 있음)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\build
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
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\GodotHub.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\GodotHub.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\GodotHub.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\GodotHub.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
