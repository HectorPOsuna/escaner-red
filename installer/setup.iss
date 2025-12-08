; Network Scanner & Monitor - Inno Setup Script
; Genera un instalador profesional para Windows

#define MyAppName "Network Scanner & Monitor"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Network Scanner Team"
#define MyAppURL "https://github.com/HectorPOsuna/escaner-red"
#define MyAppExeName "NetworkScanner.UI.exe"
#define MyServiceExeName "NetworkScanner.Service.exe"

[Setup]
; Información básica
AppId={{8F4A2B3C-9D1E-4F5A-8B2C-3D4E5F6A7B8C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\NetworkScanner
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename=NetworkScanner_v{#MyAppVersion}_Setup
; SetupIconFile=..\docs\icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Desinstalador
UninstallDisplayIcon={app}\UI\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "installwatchdog"; Description: "Instalar Watchdog (monitoreo externo - recomendado para producción)"; GroupDescription: "Watchdog:"

[Files]
; Servicio
Source: "..\dist\Service\*"; DestDir: "{app}\Service"; Flags: ignoreversion recursesubdirs createallsubdirs
; UI
Source: "..\dist\UI\*"; DestDir: "{app}\UI"; Flags: ignoreversion recursesubdirs createallsubdirs
; Watchdog (opcional)
Source: "..\dist\Watchdog\*"; DestDir: "{app}\Watchdog"; Flags: ignoreversion recursesubdirs createallsubdirs; Tasks: installwatchdog
; Agent PowerShell
Source: "..\agent\NetworkScanner.ps1"; DestDir: "{app}\Agent"; Flags: ignoreversion
Source: "..\agent\config.ps1"; DestDir: "{app}\Agent"; Flags: ignoreversion
; Installer Helper
Source: "..\dist\Installer\NetworkScanner.Installer.exe"; DestDir: "{app}\Installer"; Flags: ignoreversion
; Documentación
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
Name: "{app}\Logs"; Permissions: users-modify
Name: "{app}\Data"; Permissions: users-modify

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\UI\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\UI\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Instalar servicio principal
Filename: "{app}\Installer\NetworkScanner.Installer.exe"; Parameters: "install ""{app}\Service\{#MyServiceExeName}"""; StatusMsg: "Instalando servicio Windows..."; Flags: runhidden waituntilterminated
; Instalar watchdog (si se seleccionó)
Filename: "sc.exe"; Parameters: "create NetworkScannerWatchdog binPath= ""{app}\Watchdog\NetworkScanner.Watchdog.exe"" start= auto"; StatusMsg: "Instalando servicio Watchdog..."; Flags: runhidden waituntilterminated; Tasks: installwatchdog
Filename: "sc.exe"; Parameters: "description NetworkScannerWatchdog ""Watchdog para Network Scanner Service"""; Flags: runhidden waituntilterminated; Tasks: installwatchdog
Filename: "sc.exe"; Parameters: "start NetworkScannerWatchdog"; Flags: runhidden waituntilterminated; Tasks: installwatchdog
; Abrir UI al finalizar (opcional)
Filename: "{app}\UI\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Desinstalar watchdog (si existe)
Filename: "sc.exe"; Parameters: "stop NetworkScannerWatchdog"; RunOnceId: "StopWatchdog"; Flags: runhidden
Filename: "sc.exe"; Parameters: "delete NetworkScannerWatchdog"; RunOnceId: "DeleteWatchdog"; Flags: runhidden
; Desinstalar servicio principal
Filename: "{app}\Installer\NetworkScanner.Installer.exe"; Parameters: "uninstall"; RunOnceId: "UninstallService"; Flags: runhidden waituntilterminated

[Code]
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
  OSVersion: TWindowsVersion;
begin
  Result := True;
  
  // Verificar Windows 10 o superior
  GetWindowsVersionEx(OSVersion);
  if OSVersion.Major < 10 then
  begin
    MsgBox('Este software requiere Windows 10 o superior.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  // Verificar PowerShell
  if not Exec('powershell.exe', '-Command "exit 0"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    MsgBox('PowerShell no está disponible. Este software requiere PowerShell 5.1 o superior.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Actualizar appsettings.json con rutas correctas
    SaveStringToFile(ExpandConstant('{app}\Service\appsettings.json'), 
      '{'#13#10 +
      '  "ScannerSettings": {'#13#10 +
      '    "IntervalMinutes": 5,'#13#10 +
      '    "ScriptPath": "' + ExpandConstant('{app}') + '\\Agent\\NetworkScanner.ps1",'#13#10 +
      '    "TimeoutMinutes": 10,'#13#10 +
      '    "ApiUrl": "http://localhost/api/receive.php",'#13#10 +
      '    "EnableDetailedLogging": true'#13#10 +
      '  },'#13#10 +
      '  "Logging": {'#13#10 +
      '    "LogLevel": {'#13#10 +
      '      "Default": "Information"'#13#10 +
      '    }'#13#10 +
      '  }'#13#10 +
      '}', False);
  end;
end;
