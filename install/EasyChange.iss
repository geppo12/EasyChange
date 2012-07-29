[Setup]
AppName=EasyChange
AppVerName=1.1.1.27
DefaultDirName={pf}\EasyChange
DefaultGroupName=EasyChange
UninstallDisplayIcon={app}\EasyChange.exe
Compression=lzma
SolidCompression=yes
OutputDir=.

[Files]
Source: "Easychange.exe"; DestDir: "{app}"
Source: "EasyChange.chm"; DestDir: "{app}"

[Icons]
Name: {group}\EasyChange; Filename: {app}\EasyChange.exe
Name: {group}\EasyChange Manual; Filename: {app}\EasyChange.chm
Name: {group}\Uninstall; Filename: {uninstallexe}
Name: {commondesktop}\EasyChange; Filename: {app}\EasyChange.exe;
Name: {userappdata}\Microsoft\Internet Explorer\Quick Launch\EasyChange; Filename: {app}\EasyChange.exe;

