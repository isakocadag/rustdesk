#define MyAppName "Ossis Remote Control"
#define MyAppVersion "1.4.10"
#define MyAppPublisher "Ossis Bilişim"
#define MyAppExeName "OssisRemoteControl.exe"

[Setup]
AppId={{FB619377-9D13-4D31-8D93-OSSISREMOTE01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion=1.4.10.0
VersionInfoProductVersion=1.4.10
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
SetupIconFile=..\flutter\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName},0
SetupLogging=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Files]
Source: "..\rustdesk\*"; DestDir: "{app}"; Excludes: "rustdesk.exe"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "postinstall.cmd"; DestDir: "{app}"; Flags: ignoreversion

[InstallDelete]
Type: files; Name: "{app}\rustdesk.exe"

[Icons]
Name: "{autodesktop}\Ossis Remote Control"; Filename: "{app}\OssisRemoteControl.exe"
Name: "{group}\Ossis Remote Control"; Filename: "{app}\OssisRemoteControl.exe"

[Run]
Filename: "{cmd}"; Parameters: "/c ""{app}\postinstall.cmd"" config"; Flags: runasoriginaluser runhidden waituntilterminated
Filename: "{app}\postinstall.cmd"; Flags: runhidden waituntilterminated
Filename: "{app}\OssisRemoteControl.exe"; Description: "Ossis Remote Control'ü çalıştır"; Flags: nowait postinstall skipifsilent


[Registry]
Root: HKCR; Subkey: "ossisremote"; ValueType: string; ValueName: ""; ValueData: "URL:Ossis Remote Control Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "ossisremote"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "ossisremote\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"",0"
Root: HKCR; Subkey: "ossisremote\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[UninstallRun]
Filename: "{sys}\sc.exe"; Parameters: "stop RustDesk"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete RustDesk"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "stop OssisRemoteControl"; Flags: runhidden
Filename: "{sys}\sc.exe"; Parameters: "delete OssisRemoteControl"; Flags: runhidden
