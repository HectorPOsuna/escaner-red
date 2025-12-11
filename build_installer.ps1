# Build Installer Script
# Compila todos los proyectos y empaqueta la solución para despliegue

param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Network Scanner - Build & Package Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Rutas
$RootDir = $PSScriptRoot
$DistDir = Join-Path $RootDir "dist"
$PackageDir = Join-Path $DistDir "NetworkScanner_Package"

# Limpiar dist
if (Test-Path $DistDir) {
    Write-Host "Limpiando directorio dist..." -ForegroundColor Yellow
    Remove-Item $DistDir -Recurse -Force
}
New-Item -ItemType Directory -Path $PackageDir | Out-Null
New-Item -ItemType Directory -Path "$PackageDir\Database" | Out-Null
New-Item -ItemType Directory -Path "$PackageDir\Server" | Out-Null

# --------------------------------------------------------------------------------
# 1. Compilar Servicio Windows
# --------------------------------------------------------------------------------
Write-Host "1. Compilando Servicio (src)..." -ForegroundColor Green
$ServiceProject = Join-Path $RootDir "src\NetworkScanner.Service\NetworkScanner.Service.csproj"
$ServiceOutput = Join-Path $PackageDir "Service"

dotnet publish $ServiceProject `
    -c $Configuration `
    -r win-x64 `
    --self-contained false `
    -o $ServiceOutput

if ($LASTEXITCODE -ne 0) { Write-Error "Falló compilación del servicio"; exit 1 }

# --------------------------------------------------------------------------------
# 2. Compilar UI (WPF)
# --------------------------------------------------------------------------------
Write-Host "2. Compilando UI (src)..." -ForegroundColor Green
$UIProject = Join-Path $RootDir "src\NetworkScanner.UI\NetworkScanner.UI.csproj"
$UIOutput = Join-Path $PackageDir "UI"

dotnet publish $UIProject `
    -c $Configuration `
    -r win-x64 `
    --self-contained false `
    -o $UIOutput

if ($LASTEXITCODE -ne 0) { Write-Error "Falló compilación de la UI"; exit 1 }

# --------------------------------------------------------------------------------
# 3. Copiar Scripts del Agente
# --------------------------------------------------------------------------------
Write-Host "3. Copiando Agente PowerShell..." -ForegroundColor Green
$AgentSrc = Join-Path $RootDir "agent"
$AgentDest = Join-Path $PackageDir "Agent"
New-Item -ItemType Directory -Path $AgentDest | Out-Null

Copy-Item "$AgentSrc\NetworkScanner.ps1" -Destination $AgentDest
Copy-Item "$AgentSrc\config.ps1" -Destination $AgentDest

# --------------------------------------------------------------------------------
# 4. Copiar Backend PHP (Unificado)
# --------------------------------------------------------------------------------
Write-Host "4. Copiando Backend PHP..." -ForegroundColor Green
Copy-Item "$RootDir\server\api\receive.php" -Destination "$PackageDir\Server\receive.php"
Copy-Item "$RootDir\server\webroot\*" -Destination "$PackageDir\Server" -Recurse
Copy-Item "$RootDir\.env" -Destination "$PackageDir\Server\.env.example" # Plantilla

# --------------------------------------------------------------------------------
# 5. Copiar Scripts de Base de Datos
# --------------------------------------------------------------------------------
Write-Host "5. Copiando Scripts SQL..." -ForegroundColor Green
$DbSrc = Join-Path $RootDir "database\migrations"
Copy-Item "$DbSrc\*.sql" -Destination "$PackageDir\Database"
# Copy-Item "$DbSrc\*.php" -Destination "$PackageDir\Database"

# --------------------------------------------------------------------------------
# 6. Copiar Scripts de Instalación
# --------------------------------------------------------------------------------
Write-Host "6. Copiando Scripts de Despliegue..." -ForegroundColor Green
Copy-Item "$RootDir\agent-service\install-service.ps1" -Destination $PackageDir

# --------------------------------------------------------------------------------
# 7. Crear README de Despliegue
# --------------------------------------------------------------------------------
$ReadmeContent = @"
# Network Scanner - Paquete de Instalación

## Estructura
- Service/  -> Servicio de Windows
- UI/       -> Icono de Bandeja
- Agent/    -> Scripts de PowerShell
- Server/   -> API Backend (PHP)
- Database/ -> Scripts SQL de inicialización

## Instalación Rápida

1. **Instalar Dependencias**
   - Ejecutar 'install-php.ps1' como Administrador

2. **Base de Datos**
   - Ejecutar 'Database\init_db.php'

3. **Backend**
   - Copiar 'Server\receive.php' a tu servidor web (Apache/Nginx/IIS)
   - Configurar '.env' en el servidor

4. **Agente y Servicio**
   - Editar 'Agent\config.ps1' con la URL de tu API
   - Ejecutar 'install-service.ps1' como Administrador

5. **UI (System Tray)**
   - Ejecutar 'UI\NetworkScannerUI.exe'
   - (El instalador ya debería haber configurado el auto-arranque)
"@
Set-Content -Path "$PackageDir\LEEME_INSTALACION.md" -Value $ReadmeContent

# --------------------------------------------------------------------------------
# 8. Generar Instalador .EXE (Inno Setup)
# --------------------------------------------------------------------------------
Write-Host "8. Generando Instalador EXE..." -ForegroundColor Green

$InnoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $InnoSetupPath)) {
    $InnoSetupPath = "C:\Program Files\Inno Setup 6\ISCC.exe"
}

if (Test-Path $InnoSetupPath) {
    $IssPath = Join-Path $RootDir "installer\setup.iss"
    
    # Ejecutar compilador
    $Process = Start-Process -FilePath $InnoSetupPath -ArgumentList """$IssPath""" -Wait -NoNewWindow -PassThru
    
    if ($Process.ExitCode -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "INSTALADOR EXE GENERADO EXITOSAMENTE" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Ubicación: $DistDir\NetworkScanner_Setup.exe" -ForegroundColor Cyan
    } else {
        Write-Error "Falló Inno Setup (Exit Code: $($Process.ExitCode))"
    }
} else {
    Write-Host "⚠️  ADVERTENCIA: Inno Setup no encontrado." -ForegroundColor Yellow
    Write-Host "   Se generó el paquete ZIP pero NO el instalador EXE." -ForegroundColor Yellow
    Write-Host "   Instala Inno Setup 6+ para generar el ejecutable final." -ForegroundColor Gray
    
    # Fallback a ZIP si no hay Inno Setup
    Write-Host "   Generando ZIP de respaldo..." -ForegroundColor Cyan
    $ZipPath = Join-Path $DistDir "NetworkScanner_Package.zip"
    Compress-Archive -Path "$PackageDir\*" -DestinationPath $ZipPath -Force
    Write-Host "   ZIP generado en: $ZipPath" -ForegroundColor Cyan
}

Write-Host ""
