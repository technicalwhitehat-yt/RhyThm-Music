[Setup]
AppId=B9F6E402-0CAE-4045-BDE6-14BD6C39C4EA
AppVersion=1.12.0+25
AppName=RhyThm Music
AppPublisher=anandnet
AppPublisherURL=https://github.com/technicalwhitehat-yt/RhyThm-Music
AppSupportURL=https://github.com/technicalwhitehat-yt/RhyThm-Music
AppUpdatesURL=https://github.com/technicalwhitehat-yt/RhyThm-Music
DefaultDirName={autopf}\rhythmmusic
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=rhythmmusic-1.12.0
Compression=lzma
SolidCompression=yes
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequired=lowest
LicenseFile=..\..\LICENSE
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\rhythmmusic.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\RhyThm Music"; Filename: "{app}\rhythmmusic.exe"
Name: "{autodesktop}\RhyThm Music"; Filename: "{app}\rhythmmusic.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\rhythmmusic.exe"; Description: "{cm:LaunchProgram,{#StringChange('RhyThm Music', '&', '&&')}}"; Flags: nowait postinstall skipifsilent
