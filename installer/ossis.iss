#define MyAppName "Ossis Remote Control"
#define MyAppVersion "1.4.9"
#define MyAppPublisher "Ossis Bilişim"
#define MyAppExeName "OssisRemoteControl.exe"

[Setup]
AppId={{FB619377-9D13-4D31-8D93-OSSISREMOTE01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion=1.4.9.0
VersionInfoProductVersion=1.4.9
VersionInfoCopyright=Copyright | Ossis Bilişim Teknolojileri.
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Ossis Remote Control
DefaultGroupName={#MyAppName}
OutputDir=..\installer-output
OutputBaseFilename=OssisRemoteControl-Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#MyAppName}
SetupLogging=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Files]
Source: "..\rustdesk\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "postinstall.cmd"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autodesktop}\Ossis Remote Control"; Filename: "{app}\OssisRemoteControl.exe"
Name: "{group}\Ossis Remote Control"; Filename: "{app}\OssisRemoteControl.exe"

[Run]
Filename: "{app}\postinstall.cmd"; Flags: runhidden waituntilterminated
Filename: "{app}\OssisRemoteControl.exe"; Description: "Ossis Remote Control'ü çalıştır"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\sc.exe"; Parameters: "stop RustDesk"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete RustDesk"; Flags: runhidden
