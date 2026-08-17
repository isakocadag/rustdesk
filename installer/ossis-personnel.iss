#define MyAppName "Ossis Support Console"
#define MyAppVersion "1.4.10"
#define MyAppPublisher "Ossis Bilişim Teknolojileri"
#define MyAppExeName "OssisSupportConsole.exe"

[Setup]
AppId={{D07BCA92-47A1-4C95-A45B-055155495301}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion=1.4.10.0
VersionInfoProductVersion=1.4.10
VersionInfoCopyright=Copyright | Ossis Bilişim Teknolojileri.
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Ossis Support Console
DefaultGroupName={#MyAppName}
OutputDir=..\installer-output
OutputBaseFilename=OssisSupportConsole-Setup
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
Source: "..\rustdesk-personnel\*"; DestDir: "{app}"; Excludes: "rustdesk.exe"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "postinstall-personnel.cmd"; DestDir: "{app}"; Flags: ignoreversion

[InstallDelete]
Type: files; Name: "{app}\rustdesk.exe"

[Icons]
Name: "{autodesktop}\Ossis Support Console"; Filename: "{app}\OssisSupportConsole.exe"
Name: "{group}\Ossis Support Console"; Filename: "{app}\OssisSupportConsole.exe"

[Run]
Filename: "{cmd}"; Parameters: "/c ""{app}\postinstall-personnel.cmd"" config"; Flags: runasoriginaluser runhidden waituntilterminated
Filename: "{app}\OssisSupportConsole.exe"; Description: "Ossis Support Console'u çalıştır"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\sc.exe"; Parameters: "stop RustDesk"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete RustDesk"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "stop OssisSupportConsole"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete OssisSupportConsole"; Flags: runhidden