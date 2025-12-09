; Script de Inno Setup para Network Scanner
; Genera un instalador único .exe que incluye Servicio, UI, Agente y Herramientas

#define MyAppName "Network Scanner Agent"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "TuEmpresa"
#define MyAppURL "http://www.tuempresa.com/"
#define MyAppExeName "NetworkScanner.UI.exe"
#define MyServiceExeName "NetworkScanner.Service.exe"

[Setup]
; Identificación
AppId={{00000000-0000-0000-0000-000000000000}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Directorio de Instalación default (Program Files)
DefaultDirName={autopf}\NetworkScanner
DefaultGroupName={#MyAppName}

; Opciones
DisableProgramGroupPage=yes
OutputBaseFilename=NetworkScanner_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Dirs]
; Crear directorio de logs en ProgramData con permisos full para Todos (o Users)
Name: "{commonappdata}\NetworkScanner\Logs"; Permissions: users-modify

[Files]
; Servicio Windows
Source: "..\dist\NetworkScanner_Package\Service\*"; DestDir: "{app}\Service"; Flags: ignoreversion recursesubdirs createallsubdirs

; Interfaz UI
Source: "..\dist\NetworkScanner_Package\UI\*"; DestDir: "{app}\UI"; Flags: ignoreversion recursesubdirs createallsubdirs

; Agente PowerShell
Source: "..\dist\NetworkScanner_Package\Agent\*"; DestDir: "{app}\Agent"; Flags: ignoreversion recursesubdirs createallsubdirs

; Backend y DB (Como referencia/tools)
Source: "..\dist\NetworkScanner_Package\Server\*"; DestDir: "{app}\Server"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\dist\NetworkScanner_Package\Database\*"; DestDir: "{app}\Database"; Flags: ignoreversion recursesubdirs createallsubdirs

; Readme
Source: "..\dist\NetworkScanner_Package\LEEME_INSTALACION.md"; DestDir: "{app}"; Flags: isreadme

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Icons]
; Acceso directo en Menú Inicio
Name: "{group}\{#MyAppName}"; Filename: "{app}\UI\{#MyAppExeName}"
Name: "{group}\Ver Logs"; Filename: "{commonappdata}\NetworkScanner\Logs"

; Acceso directo en Escritorio
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\UI\{#MyAppExeName}"; Tasks: desktopicon

; Acceso directo en Startup (para la UI)
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\UI\{#MyAppExeName}"

[Run]
; 1. Instalar Servicio (usando sc.exe)
; Se asegura de borrarlo primero por si existe corrupto
Filename: "sc.exe"; Parameters: "stop NetworkScannerService"; Flags: runhidden; StatusMsg: "Deteniendo servicio anterior..."; Check: ServiceExists
Filename: "sc.exe"; Parameters: "delete NetworkScannerService"; Flags: runhidden; StatusMsg: "Eliminando servicio anterior..."; Check: ServiceExists

; Crear el servicio. binPath debe apuntar al exe. start= auto.
Filename: "sc.exe"; Parameters: "create NetworkScannerService binPath= ""{app}\Service\{#MyServiceExeName}"" start= auto DisplayName= ""Network Scanner Service"""; Flags: runhidden; StatusMsg: "Registrando servicio..."
Filename: "sc.exe"; Parameters: "description NetworkScannerService ""Agente de monitoreo de red y detección de conflictos"""; Flags: runhidden
Filename: "sc.exe"; Parameters: "failure NetworkScannerService reset= 86400 actions= restart/60000/restart/60000/restart/60000"; Flags: runhidden; StatusMsg: "Configurando recuperación..."

; 2. Iniciar Servicio
Filename: "sc.exe"; Parameters: "start NetworkScannerService"; Flags: runhidden; StatusMsg: "Iniciando servicio..."

; 3. Iniciar UI
Filename: "{app}\UI\{#MyAppExeName}"; Description: "Iniciar aplicación de bandeja"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; 1. Detener e iniciar borrado del servicio
Filename: "sc.exe"; Parameters: "stop NetworkScannerService"; Flags: runhidden
Filename: "sc.exe"; Parameters: "delete NetworkScannerService"; Flags: runhidden
Filename: "taskkill"; Parameters: "/f /im {#MyAppExeName}"; Flags: runhidden; StatusMsg: "Cerrando aplicación..."

[Code]
// Función para verificar si servicio existe (simple check)
function ServiceExists: Boolean;
var
  ResultCode: Integer;
begin
  // Ejecutar sc query. Si retorna 0 (Success) es que existe. 1060 es que no existe.
  if Exec('sc.exe', 'query NetworkScannerService', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := (ResultCode = 0);
  end
  else
  begin
    Result := False;
  end;
end;
