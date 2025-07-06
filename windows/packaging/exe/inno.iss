#define MyAppName        "Brisk"
#define MyAppVersion     "BRISK_VERSION"
#define MyAppSupportLink "https://github.com/BrisklyDev/brisk"
#define MyAppAuthor      "Amin Beheshti"
#define CurrentYear      GetDateTimeString('yyyy','','')

[Setup]
AppId=06368BAD-E63B-4F67-9BCF-9C20EC23C38D
AppName={#MyAppName}
AppVersion={#MyAppVersion}

VersionInfoDescription={#MyAppName} installer
VersionInfoProductName={#MyAppName}
VersionInfoVersion={#MyAppVersion}

AppCopyright=(c) {#CurrentYear} {#MyAppAuthor}

UninstallDisplayName={#MyAppName} {#MyAppVersion}
UninstallDisplayIcon={app}\brisk.exe
AppPublisher={#MyAppAuthor}

AppPublisherURL={#MyAppSupportLink}
AppSupportURL={#MyAppSupportLink}
AppUpdatesURL={#MyAppSupportLink}

WizardStyle=modern

ShowLanguageDialog=yes
UsePreviousLanguage=no
LanguageDetectionMethod=uilanguage

DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=OUTPUT_DIR
OutputBaseFilename={#MyAppName}
SetupIconFile=SETUP_ICON_FILE
Compression=lzma
DisableDirPage=no
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "BASE_DIR\build\windows\x64\runner\Release\brisk.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\hotkey_manager_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\tray_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\rhttp.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\screen_retriever_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\windows_single_instance_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\window_manager_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\window_to_front_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\/data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "BASE_DIR\build\windows\x64\runner\Release\updater\brisk_auto_updater.exe"; DestDir: "{app}\updater"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\updater\flutter_windows.dll"; DestDir: "{app}\updater"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\updater\screen_retriever_windows_plugin.dll"; DestDir: "{app}\updater"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\updater\window_manager_plugin.dll"; DestDir: "{app}\updater"; Flags: ignoreversion
Source: "BASE_DIR\build\windows\x64\runner\Release\updater\data\*"; DestDir: "{app}\updater\/data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Brisk"; Filename: "{app}\brisk.exe"
Name: "{autodesktop}\Brisk"; Filename: "{app}\brisk.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\brisk.exe"; Description: "{cm:LaunchProgram,Brisk}"; Flags: nowait postinstall skipifsilent
