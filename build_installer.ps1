# Build Installer Script
# Compila todos los proyectos y genera el instalador final

param(
    [string]$Configuration = "Release",
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Network Scanner & Monitor - Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Rutas
$RootDir = $PSScriptRoot
$SrcDir = Join-Path $RootDir "src"
$DistDir = Join-Path $RootDir "dist"
$InstallerDir = Join-Path $RootDir "installer"

# Limpiar dist
if (Test-Path $DistDir) {
    Write-Host "Limpiando directorio dist..." -ForegroundColor Yellow
    Remove-Item $DistDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DistDir | Out-Null

# 1. Compilar y publicar el Servicio
Write-Host ""
Write-Host "1. Compilando NetworkScanner.Service..." -ForegroundColor Green
$ServiceProject = Join-Path $SrcDir "NetworkScanner.Service\NetworkScanner.Service.csproj"
$ServiceOutput = Join-Path $DistDir "Service"

dotnet publish $ServiceProject `
    -c $Configuration `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=false `
    -o $ServiceOutput

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Falló la compilación del servicio" -ForegroundColor Red
    exit 1
}

# 2. Compilar y publicar la UI
Write-Host ""
Write-Host "2. Compilando NetworkScanner.UI..." -ForegroundColor Green
$UIProject = Join-Path $SrcDir "NetworkScanner.UI\NetworkScanner.UI.csproj"
$UIOutput = Join-Path $DistDir "UI"

dotnet publish $UIProject `
    -c $Configuration `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=false `
    -o $UIOutput

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Falló la compilación de la UI" -ForegroundColor Red
    exit 1
}

# 3. Compilar y publicar el Installer
Write-Host ""
Write-Host "3. Compilando NetworkScanner.Installer..." -ForegroundColor Green
$InstallerProject = Join-Path $SrcDir "NetworkScanner.Installer\NetworkScanner.Installer.csproj"
$InstallerOutput = Join-Path $DistDir "Installer"

dotnet publish $InstallerProject `
    -c $Configuration `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -o $InstallerOutput

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Falló la compilación del installer" -ForegroundColor Red
    exit 1
}

# 4. Compilar y publicar el Watchdog
Write-Host ""
Write-Host "4. Compilando NetworkScanner.Watchdog..." -ForegroundColor Green
$WatchdogProject = Join-Path $SrcDir "NetworkScanner.Watchdog\NetworkScanner.Watchdog.csproj"
$WatchdogOutput = Join-Path $DistDir "Watchdog"

dotnet publish $WatchdogProject `
    -c $Configuration `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=false `
    -o $WatchdogOutput

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Falló la compilación del watchdog" -ForegroundColor Red
    exit 1
}

# 5. Verificar Inno Setup
Write-Host ""
Write-Host "4. Verificando Inno Setup..." -ForegroundColor Green

$InnoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $InnoSetupPath)) {
    Write-Host "ADVERTENCIA: Inno Setup no encontrado en: $InnoSetupPath" -ForegroundColor Yellow
    Write-Host "Descárgalo desde: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Compilación completada. Archivos en: $DistDir" -ForegroundColor Green
    Write-Host "Para generar el instalador, instala Inno Setup y ejecuta este script nuevamente." -ForegroundColor Yellow
    exit 0
}

# 6. Generar instalador con Inno Setup
Write-Host ""
Write-Host "6. Generando instalador con Inno Setup..." -ForegroundColor Green

$SetupScript = Join-Path $InstallerDir "setup.iss"
& $InnoSetupPath $SetupScript /DMyAppVersion=$Version

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Falló la generación del instalador" -ForegroundColor Red
    exit 1
}

# Resultado
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "BUILD COMPLETADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Instalador generado en:" -ForegroundColor Cyan
$InstallerFile = Join-Path $DistDir "NetworkScanner_v${Version}_Setup.exe"
Write-Host "  $InstallerFile" -ForegroundColor White
Write-Host ""
Write-Host "Tamaño del instalador:" -ForegroundColor Cyan
$FileSize = (Get-Item $InstallerFile).Length / 1MB
Write-Host "  $([math]::Round($FileSize, 2)) MB" -ForegroundColor White
Write-Host ""
