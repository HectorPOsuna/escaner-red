# Script de instalación rápida del servicio
# Ejecutar como Administrador

param(
    [string]$Action = "install"
)

$ServiceName = "NetworkScannerService"
$ServiceDisplayName = "Network Scanner Service"
$ServiceDescription = "Servicio que ejecuta escaneos de red periódicos y envía datos a la API central"

# Obtener ruta del ejecutable (asume que está compilado)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExePath = Join-Path $ScriptDir "bin\Release\net8.0-windows\NetworkScannerService.exe"

function Install-NetworkService {
    Write-Host "🔧 Instalando servicio..." -ForegroundColor Cyan
    
    # Verificar que el ejecutable existe
    if (-not (Test-Path $ExePath)) {
        Write-Host "❌ Error: No se encontró el ejecutable en: $ExePath" -ForegroundColor Red
        Write-Host "   Por favor, compila el proyecto primero con: dotnet build -c Release" -ForegroundColor Yellow
        exit 1
    }
    
    # Verificar si el servicio ya existe
    $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Host "⚠️  El servicio ya existe. Eliminando primero..." -ForegroundColor Yellow
        Uninstall-NetworkService
    }
    
    # Crear el servicio
    try {
        sc.exe create $ServiceName binPath= "`"$ExePath`"" start= auto DisplayName= $ServiceDisplayName
        sc.exe description $ServiceName $ServiceDescription
        
        Write-Host "✅ Servicio instalado correctamente" -ForegroundColor Green
        Write-Host "   Nombre: $ServiceName" -ForegroundColor Gray
        Write-Host "   Ejecutable: $ExePath" -ForegroundColor Gray
        
        # Preguntar si desea iniciar el servicio
        $start = Read-Host "¿Desea iniciar el servicio ahora? (S/N)"
        if ($start -eq "S" -or $start -eq "s") {
            Start-NetworkService
        }
    }
    catch {
        Write-Host "❌ Error al instalar el servicio: $_" -ForegroundColor Red
        exit 1
    }
}

function Uninstall-NetworkService {
    Write-Host "🗑️  Desinstalando servicio..." -ForegroundColor Cyan
    
    # Detener el servicio si está corriendo
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Write-Host "   Deteniendo servicio..." -ForegroundColor Yellow
        Stop-Service -Name $ServiceName -Force
        Start-Sleep -Seconds 2
    }
    
    # Eliminar el servicio
    sc.exe delete $ServiceName
    
    Write-Host "✅ Servicio desinstalado correctamente" -ForegroundColor Green
}

function Start-NetworkService {
    Write-Host "▶️  Iniciando servicio..." -ForegroundColor Cyan
    
    try {
        Start-Service -Name $ServiceName
        Write-Host "✅ Servicio iniciado correctamente" -ForegroundColor Green
        
        # Mostrar estado
        Get-Service -Name $ServiceName | Format-Table -AutoSize
    }
    catch {
        Write-Host "❌ Error al iniciar el servicio: $_" -ForegroundColor Red
    }
}

function Stop-NetworkService {
    Write-Host "⏹️  Deteniendo servicio..." -ForegroundColor Cyan
    
    try {
        Stop-Service -Name $ServiceName -Force
        Write-Host "✅ Servicio detenido correctamente" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error al detener el servicio: $_" -ForegroundColor Red
    }
}

function Get-ServiceStatus {
    Write-Host "📊 Estado del servicio:" -ForegroundColor Cyan
    
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        $service | Format-Table -AutoSize
        
        # Mostrar logs recientes
        $logPath = "C:\Logs\MiServicio\service_$(Get-Date -Format 'yyyyMMdd').log"
        if (Test-Path $logPath) {
            Write-Host "`n📄 Últimas 10 líneas del log:" -ForegroundColor Cyan
            Get-Content $logPath -Tail 10
        }
    }
    else {
        Write-Host "❌ El servicio no está instalado" -ForegroundColor Red
    }
}

# Verificar que se ejecuta como administrador
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ Este script debe ejecutarse como Administrador" -ForegroundColor Red
    Write-Host "   Haz clic derecho en PowerShell y selecciona 'Ejecutar como administrador'" -ForegroundColor Yellow
    exit 1
}

# Ejecutar acción
switch ($Action.ToLower()) {
    "install" { Install-NetworkService }
    "uninstall" { Uninstall-NetworkService }
    "start" { Start-NetworkService }
    "stop" { Stop-NetworkService }
    "status" { Get-ServiceStatus }
    "restart" {
        Stop-NetworkService
        Start-Sleep -Seconds 2
        Start-NetworkService
    }
    default {
        Write-Host "Uso: .\install-service.ps1 -Action [install|uninstall|start|stop|status|restart]" -ForegroundColor Yellow
    }
}
