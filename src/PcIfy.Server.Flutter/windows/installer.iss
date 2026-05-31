; Inno Setup script for pc-ify server (Flutter)
; Run: iscc installer.iss from the windows/ folder, or let CI do it.

[Setup]
AppName=pc-ify server
AppVersion=1.0.0
AppPublisher=pc-ify
DefaultDirName={autopf}\pc-ify server
DefaultGroupName=pc-ify server
OutputBaseFilename=pcify-server-setup
Compression=lzma2
SolidCompression=yes
; Installer icon — update path once app icon assets are added.
; SetupIconFile=..\assets\icons\app_icon.ico

[Files]
; Include the entire Flutter Windows release output.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\pc-ify server"; Filename: "{app}\pcify_server.exe"
Name: "{group}\Uninstall pc-ify server"; Filename: "{uninstallexe}"
Name: "{commondesktop}\pc-ify server"; Filename: "{app}\pcify_server.exe"; Tasks: desktopicon

[Tasks]
Name: desktopicon; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\pcify_server.exe"; Description: "Launch pc-ify server"; Flags: nowait postinstall skipifsilent
