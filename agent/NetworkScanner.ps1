<#
.SYNOPSIS
    Agente de Monitoreo de Red - Escáner de IPs
    
.DESCRIPTION
    Este script escanea una subred especificada para identificar direcciones IP activas e inactivas.
    Utiliza Test-Connection (o Test-NetConnection) para verificar la conectividad.
    Soporta ejecución en paralelo en PowerShell 7+ para mayor velocidad.
    Genera dos archivos de salida: active_ips.txt y inactive_ips.txt.

.NOTES
    Versión: 1.0.0
    Autor: Monitor de Actividad de Protocolos de Red Team
    Fecha: 2025
#>

# ==============================================================================
# SECCIÓN 1: CONFIGURACIÓN
# ==============================================================================

# Subred a escanear (Formato C: xxx.xxx.xxx.)
# Se asume máscara /24 (1-254)
$SubnetPrefix = "192.168.1."

# Archivos de salida
$OutputFileActive = Join-Path -Path $PSScriptRoot -ChildPath "active_ips.txt"
$OutputFileInactive = Join-Path -Path $PSScriptRoot -ChildPath "inactive_ips.txt"

# Configuración de Ping
$PingCount = 1
$PingTimeoutMs = 200 # Timeout en milisegundos (ajustar según latencia de red)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   INICIANDO ESCÁNER DE RED - MONITOR DE PROTOCOLOS" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host "Subred objetivo: ${SubnetPrefix}0/24"
Write-Host "Version de PowerShell: $($PSVersionTable.PSVersion.ToString())"
Write-Host "----------------------------------------------------------------"

# ==============================================================================
# SECCIÓN 2: FUNCIONES AUXILIARES
# ==============================================================================

function Get-IpRange {
    <#
    .SYNOPSIS
        Genera el rango de IPs para una subred /24.
    .OUTPUTS
        System.String[]
    #>
    param (
        [string]$Prefix
    )
    
    $Ips = @()
    for ($i = 1; $i -lt 255; $i++) {
        $Ips += "${Prefix}${i}"
    }
    return $Ips
}

function Test-HostConnectivity {
    <#
    .SYNOPSIS
        Prueba la conectividad a una IP específica de forma silenciosa.
    .INPUTS
        IpAddress (String)
    .OUTPUTS
        PSCustomObject { IP, Status }
    #>
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$IpAddress
    )

    $IsActive = $false

    try {
        # Usar clase .NET Ping para mayor control sobre el Timeout (ms) y mejor rendimiento
        # Esto soluciona el problema de la variable $PingTimeoutMs no utilizada
        $Ping = [System.Net.NetworkInformation.Ping]::new()
        $Reply = $Ping.Send($IpAddress, $PingTimeoutMs)
        $IsActive = ($Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
        $Ping.Dispose()
    }
    catch {
        # En caso de error de ejecución (no de ping fallido), asumimos inactivo
        $IsActive = $false
    }

    return [PSCustomObject]@{
        IP = $IpAddress
        Status = if ($IsActive) { "Active" } else { "Inactive" }
    }
}

# ==============================================================================
# SECCIÓN 3: EJECUCIÓN DEL ESCANEO
# ==============================================================================

Write-Host "Generando lista de objetivos..." -ForegroundColor Yellow
$TargetIps = Get-IpRange -Prefix $SubnetPrefix
Write-Host "Objetivos generados: $($TargetIps.Count) direcciones." -ForegroundColor Green

$Results = @()
$TotalHosts = $TargetIps.Count

# Detectar capacidad de paralelismo (PowerShell 7+)
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "Modo detectado: PARALELO (Optimizado para PS 7+)" -ForegroundColor Magenta
    
    # Ejecución en paralelo usando ForEach-Object -Parallel
    # ThrottleLimit 64 permite muchos pings simultáneos
    $Results = $TargetIps | ForEach-Object -Parallel {
        $Ip = $_
        $Timeout = $using:PingTimeoutMs
        $Active = $false
        
        try {
            $Ping = [System.Net.NetworkInformation.Ping]::new()
            $Reply = $Ping.Send($Ip, $Timeout)
            $Active = ($Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
            $Ping.Dispose()
        } catch { 
            $Active = $false 
        }
        
        # Devolver objeto al hilo principal
        [PSCustomObject]@{
            IP = $Ip
            Status = if ($Active) { "Active" } else { "Inactive" }
        }
    } -ThrottleLimit 64
}
else {
    Write-Host "Modo detectado: SECUENCIAL (Compatibilidad PS 5.1)" -ForegroundColor Yellow
    Write-Host "Nota: Actualice a PowerShell 7 para mayor velocidad." -ForegroundColor DarkGray
    
    # Ejecución secuencial tradicional
    $Counter = 0
    foreach ($Ip in $TargetIps) {
        $Counter++
        if ($Counter % 10 -eq 0) {
            Write-Progress -Activity "Escaneando red..." -Status "Procesando $Ip" -PercentComplete (($Counter / $TotalHosts) * 100)
        }
        
        $Results += Test-HostConnectivity -IpAddress $Ip
    }
    Write-Progress -Activity "Escaneando red..." -Completed
}

# ==============================================================================
# SECCIÓN 4: PROCESAMIENTO Y EXPORTACIÓN
# ==============================================================================

Write-Host "Procesando resultados..." -ForegroundColor Yellow

# Filtrar resultados
$ActiveHosts = $Results | Where-Object { $_.Status -eq "Active" } | Select-Object -ExpandProperty IP
$InactiveHosts = $Results | Where-Object { $_.Status -eq "Inactive" } | Select-Object -ExpandProperty IP

# Exportar a archivos
try {
    if ($ActiveHosts) {
        $ActiveHosts | Out-File -FilePath $OutputFileActive -Encoding UTF8 -Force
    } else {
        # Crear archivo vacío si no hay activos
        New-Item -Path $OutputFileActive -ItemType File -Force | Out-Null
    }

    if ($InactiveHosts) {
        $InactiveHosts | Out-File -FilePath $OutputFileInactive -Encoding UTF8 -Force
    } else {
        # Crear archivo vacío si no hay inactivos
        New-Item -Path $OutputFileInactive -ItemType File -Force | Out-Null
    }
    
    Write-Host "Resultados exportados correctamente." -ForegroundColor Green
}
catch {
    Write-Error "Error al exportar archivos: $_"
}

# ==============================================================================
# SECCIÓN 5: RESUMEN FINAL
# ==============================================================================

Write-Host "----------------------------------------------------------------"
Write-Host "RESUMEN DEL ESCANEO" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------"
Write-Host "Total IPs escaneadas : $TotalHosts"
Write-Host "IPs Activas          : $(@($ActiveHosts).Count)" -ForegroundColor Green
Write-Host "IPs Inactivas        : $(@($InactiveHosts).Count)" -ForegroundColor Red
Write-Host "----------------------------------------------------------------"
Write-Host "Archivos generados:"
Write-Host " -> $OutputFileActive"
Write-Host " -> $OutputFileInactive"
Write-Host "================================================================"
