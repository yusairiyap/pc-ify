; Inno Setup script for pc-ify client (Flutter)
; Run: iscc installer.iss from the windows/ folder, or let CI do it.

[Setup]
AppName=pc-ify
AppVersion=1.0.0
AppPublisher=pc-ify
DefaultDirName={autopf}\pc-ify
DefaultGroupName=pc-ify
OutputBaseFilename=pcify-client-setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\pc-ify"; Filename: "{app}\pcify_client.exe"
Name: "{group}\Uninstall pc-ify"; Filename: "{uninstallexe}"
Name: "{commondesktop}\pc-ify"; Filename: "{app}\pcify_client.exe"; Tasks: desktopicon

[Tasks]
Name: desktopicon; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\pcify_client.exe"; Description: "Launch pc-ify"; Flags: nowait postinstall skipifsilent
