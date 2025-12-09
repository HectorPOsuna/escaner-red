param (
    [string]$ConfigFile = ""
)

<#
.SYNOPSIS
    Agente de Monitoreo de Red - Escáner de IPs
    
.DESCRIPTION
    Este script escanea una subred especificada para identificar direcciones IP activas e inactivas.
    Utiliza Test-Connection (o Test-NetConnection) para verificar la conectividad.
    Soporta ejecución en paralelo en PowerShell 7+ para mayor velocidad.
    Genera dos archivos de salida: active_ips.txt y inactive_ips.txt.

.NOTES
    Versión: 1.1.0
    Autor: Monitor de Actividad de Protocolos de Red Team
    Fecha: 2025
#>

# ==============================================================================
# SECCIÓN 1: CONFIGURACIÓN
# ==============================================================================

# Variables de progreso
$EnableProgress = $false
$ProgressFile = ""

# Determinar archivo de configuración
# Cargar configuración
if (Test-Path $ConfigFile) {
    if ($ConfigFile.EndsWith(".json")) {
        # Cargar configuración desde JSON (Nueva UI)
        try {
            $JsonConfig = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            
            if ($JsonConfig.SubnetPrefix) { $SubnetPrefix = $JsonConfig.SubnetPrefix }
            if ($JsonConfig.StartIP) { $StartIP = $JsonConfig.StartIP }
            if ($JsonConfig.EndIP) { $EndIP = $JsonConfig.EndIP }
            
            if ($JsonConfig.OperationMode) { $OperationMode = $JsonConfig.OperationMode }
            if ($JsonConfig.EnableProgress) { $EnableProgress = $JsonConfig.EnableProgress }
            if ($JsonConfig.ProgressFile) { $ProgressFile = $JsonConfig.ProgressFile }
            
            # Valores por defecto para el resto si no vienen en JSON
            $ApiEnabled = $true
            $ApiUrl = "http://dsantana.fimaz.uas.edu.mx/server/api/receive.php"
            $ApiTimeout = 10
            $ApiRetries = 3
            $ApiRetryDelay = 2
            $PortScanEnabled = $true
            $PortScanTimeout = 500
            $PortCacheTTLMinutes = 10
            $ScanResultsFile = "scan_results.json"
            $PhpProcessorScript = "..\server\cron_process.php"
            $PhpExecutable = "php"
            
            Write-Host "[OK] Configuración JSON cargada desde $ConfigFile" -ForegroundColor Green
        }
        catch {
            Write-Warning "Error al leer config JSON: $_"
        }
    }
    else {
        # Cargar configuración desde script PowerShell (Legacy)
        . $ConfigFile
        Write-Host "[OK] Configuración cargada desde config.ps1" -ForegroundColor Green
    }
}
else {
    # Valores por defecto si no existe config
    $OperationMode = "hybrid"
    $ApiEnabled = $true
    $ApiUrl = "https://localhost/escaner-red/server/api/receive.php"
    $ApiTimeout = 10
    $ApiRetries = 3
    $ApiRetryDelay = 2
    $SubnetPrefix = "192.168.1."
    $PortScanEnabled = $true
    $PortScanTimeout = 500
    $PortCacheTTLMinutes = 10
    $ScanResultsFile = "scan_results.json"
    $PhpProcessorScript = "..\server\cron_process.php"
    $PhpExecutable = "php"
    Write-Host "[ADVERTENCIA] Usando configuración por defecto (config no encontrado)" -ForegroundColor Yellow
}

# Archivos de salida
$OutputFileReport = Join-Path -Path $PSScriptRoot -ChildPath "reporte_de_red.txt"
$ScanHistoryFile = Join-Path -Path $PSScriptRoot -ChildPath "ultimo_escaneo.txt"
$ScanResultsFile = Join-Path -Path $PSScriptRoot -ChildPath $ScanResultsFile
$PhpProcessorScript = Join-Path -Path $PSScriptRoot -ChildPath $PhpProcessorScript

# Configuración de Ping
$PingCount = 1
$PingTimeoutMs = 200

# Lista de puertos por defecto
$DefaultCommonPorts = @(
    @{Port = 21; Protocol = "FTP"; Category = "Inseguro" },
    @{Port = 22; Protocol = "SSH"; Category = "Seguro" },
    @{Port = 23; Protocol = "Telnet"; Category = "Inseguro" },
    @{Port = 25; Protocol = "SMTP"; Category = "Inseguro" },
    @{Port = 53; Protocol = "DNS"; Category = "Precaucion" },
    @{Port = 80; Protocol = "HTTP"; Category = "Inseguro" },
    @{Port = 110; Protocol = "POP3"; Category = "Inseguro" },
    @{Port = 143; Protocol = "IMAP"; Category = "Inseguro" },
    @{Port = 443; Protocol = "HTTPS"; Category = "Seguro" },
    @{Port = 445; Protocol = "SMB"; Category = "Precaucion" },
    @{Port = 993; Protocol = "IMAPS"; Category = "Seguro" },
    @{Port = 995; Protocol = "POP3S"; Category = "Seguro" },
    @{Port = 3306; Protocol = "MySQL"; Category = "Precaucion" },
    @{Port = 3389; Protocol = "RDP"; Category = "Precaucion" },
    @{Port = 5432; Protocol = "PostgreSQL"; Category = "Precaucion" },
    @{Port = 8080; Protocol = "HTTP-Alt"; Category = "Precaucion" }
)

$CommonPorts = $DefaultCommonPorts
$PortCacheFile = Join-Path -Path $PSScriptRoot -ChildPath "port_scan_cache.json"

# Detección de Dominio
try {
    $IsInDomain = (Get-WmiObject Win32_ComputerSystem).PartOfDomain
}
catch {
    $IsInDomain = $false
}

# Leer información del último escaneo
$LastScanInfo = ""
if (Test-Path $ScanHistoryFile) {
    try {
        $LastScanInfo = Get-Content $ScanHistoryFile -Raw -ErrorAction SilentlyContinue
    }
    catch {
        $LastScanInfo = "No disponible"
    }
}
else {
    $LastScanInfo = "Primer escaneo"
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   INICIANDO ESCANER DE RED - MONITOR DE PROTOCOLOS" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host "Subred objetivo: ${SubnetPrefix}0/24"
Write-Host "Modo de operacion: $OperationMode" -ForegroundColor Magenta
if ($ApiEnabled) {
    Write-Host "API URL: $ApiUrl" -ForegroundColor Cyan
}
Write-Host "Version de PowerShell: $($PSVersionTable.PSVersion.ToString())"
Write-Host "En dominio: $(if ($IsInDomain) { 'Si (usando WMI/CIM + TTL)' } else { 'No (usando solo TTL)' })"
Write-Host "Ultimo escaneo: $LastScanInfo" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------"

# ==============================================================================
# SECCIÓN 2: FUNCIONES AUXILIARES
# ==============================================================================

function Get-RemoteProtocols {
    return $null
}

# Intentar actualizar la lista de puertos comunes desde la API
$RemotePortsList = Get-RemoteProtocols
if ($RemotePortsList) {
    $CommonPorts = $RemotePortsList | Select-Object -First 50
    Write-Host "Lista de escaneo actualizada con los Top 50 protocolos de la nube." -ForegroundColor Gray
}

function Get-IpRange {
    param (
        [string]$Prefix,
        [string]$StartIP = "",
        [string]$EndIP = ""
    )
    
    $Ips = @()

    if (-not [string]::IsNullOrEmpty($StartIP) -and -not [string]::IsNullOrEmpty($EndIP)) {
        # Validar y generar rango
        try {
            $start = [System.Version]$StartIP
            $end = [System.Version]$EndIP
            
            # Asumimos /24 para simplificar lógica en este paso, 
            # pero iteramos el último octeto si los primeros 3 coinciden
            if ($start.Major -eq $end.Major -and $start.Minor -eq $end.Minor -and $start.Build -eq $end.Build) {
                # Rango simple en la misma subred
                for ($i = $start.Revision; $i -le $end.Revision; $i++) {
                    $Ips += "$($start.Major).$($start.Minor).$($start.Build).$i"
                }
            }
            else {
                # Fallback a subnet simple si el rango es complejo
                Write-Warning "Rango complejo no soportado completamente. Usando Prefijo."
                for ($i = 1; $i -lt 255; $i++) {
                    $Ips += "${Prefix}${i}"
                }
            }
        }
        catch {
            Write-Warning "Error generando rango de IPs"
        }
    }
    else {
        # Comportamiento anterior (Subred completa)
        for ($i = 1; $i -lt 255; $i++) {
            $Ips += "${Prefix}${i}"
        }
    }
    
    return $Ips
}

function Get-OSFromTTL {
    param ([int]$Ttl)
    
    if ($Ttl -le 64) {
        return "Linux/Unix"
    }
    elseif ($Ttl -le 128) {
        return "Windows"
    }
    elseif ($Ttl -le 255) {
        return "Cisco/Network Device"
    }
    else {
        return "Unknown"
    }
}

function Get-OSFromWMI {
    param ([string]$IpAddress)
    
    try {
        $CimSession = New-CimSession -ComputerName $IpAddress -ErrorAction Stop -OperationTimeoutSec 2
        $OS = Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem -ErrorAction Stop
        Remove-CimSession -CimSession $CimSession -ErrorAction SilentlyContinue
        
        if ($OS.Caption) {
            return $OS.Caption -replace 'Microsoft ', ''
        }
    }
    catch {
        return ""
    }
    
    return ""
}

function Get-MacAddress {
    param ([string]$IpAddress)
    
    try {
        if (Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue) {
            $Neighbor = Get-NetNeighbor -IPAddress $IpAddress -ErrorAction SilentlyContinue
            if ($Neighbor -and $Neighbor.LinkLayerAddress) {
                return $Neighbor.LinkLayerAddress
            }
        }
        
        $ArpOutput = arp -a $IpAddress 2>$null
        if ($ArpOutput) {
            foreach ($Line in $ArpOutput) {
                if ($Line -match $IpAddress) {
                    if ($Line -match '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})') {
                        return $Matches[0]
                    }
                }
            }
        }
    }
    catch {
        return ""
    }
    
    return ""
}

function Get-ManufacturerFromOUI {
    param ([string]$MacAddress)
    return "Desconocido"
}

function Get-OpenPorts {
    param (
        [string]$IpAddress,
        [array]$Ports,
        [int]$Timeout = 500,
        [hashtable]$Cache = @{}
    )
    
    $OpenPorts = @()
    
    foreach ($PortInfo in $Ports) {
        $CachedPort = Test-PortInCache -Cache $Cache -IpAddress $IpAddress -Port $PortInfo.Port
        
        if ($CachedPort) {
            $OpenPorts += $CachedPort
            continue
        }
        
        try {
            $TestResult = Test-NetConnection -ComputerName $IpAddress -Port $PortInfo.Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -InformationLevel Quiet
            
            if ($TestResult) {
                $Category = if ($PortInfo.Category) { $PortInfo.Category } else { "Inusual" }
                $PortResult = [PSCustomObject]@{
                    Port       = $PortInfo.Port
                    Protocol   = $PortInfo.Protocol
                    Category   = $Category
                    Status     = "Open"
                    DetectedAt = Get-Date -Format "HH:mm:ss"
                }
                $OpenPorts += $PortResult
                Add-PortToCache -Cache $Cache -IpAddress $IpAddress -PortInfo $PortResult
            }
        }
        catch {
            continue
        }
    }
    
    return $OpenPorts
}

function Read-PortCache {
    if (Test-Path $PortCacheFile) {
        try {
            $JsonContent = Get-Content $PortCacheFile -Raw -ErrorAction Stop
            $CacheData = $JsonContent | ConvertFrom-Json
            
            $Cache = @{}
            $CacheData.PSObject.Properties | ForEach-Object {
                $Cache[$_.Name] = $_.Value
            }
            return $Cache
        }
        catch {
            return @{}
        }
    }
    return @{}
}

function Write-PortCache {
    param ([hashtable]$Cache)
    
    try {
        $Cache | ConvertTo-Json -Depth 3 | Out-File -FilePath $PortCacheFile -Encoding UTF8 -Force
    }
    catch {
        Write-Warning "No se pudo guardar el cache de puertos: $_"
    }
}

function Test-PortInCache {
    param (
        [hashtable]$Cache,
        [string]$IpAddress,
        [int]$Port
    )
    
    $Key = "${IpAddress}:${Port}"
    
    if ($Cache.ContainsKey($Key)) {
        $Entry = $Cache[$Key]
        $LastScanned = [DateTime]::Parse($Entry.LastScanned)
        $Age = (Get-Date) - $LastScanned
        
        if ($Age.TotalMinutes -lt $PortCacheTTLMinutes) {
            return [PSCustomObject]@{
                Port       = $Entry.Port
                Protocol   = $Entry.Protocol
                Category   = $Entry.Category
                Status     = $Entry.Status
                DetectedAt = $Entry.DetectedAt
            }
        }
    }
    
    return $null
}

function Add-PortToCache {
    param (
        [hashtable]$Cache,
        [string]$IpAddress,
        [PSCustomObject]$PortInfo
    )
    
    $Key = "${IpAddress}:$($PortInfo.Port)"
    
    $Cache[$Key] = @{
        IP          = $IpAddress
        Port        = $PortInfo.Port
        Protocol    = $PortInfo.Protocol
        Category    = $PortInfo.Category
        Status      = $PortInfo.Status
        LastScanned = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        DetectedAt  = $PortInfo.DetectedAt
    }
}

function Clean-ExpiredCache {
    param ([hashtable]$Cache)
    
    $ExpiredKeys = @()
    
    foreach ($Key in $Cache.Keys) {
        $Entry = $Cache[$Key]
        $LastScanned = [DateTime]::Parse($Entry.LastScanned)
        $Age = (Get-Date) - $LastScanned
        
        if ($Age.TotalMinutes -ge $PortCacheTTLMinutes) {
            $ExpiredKeys += $Key
        }
    }
    
    foreach ($Key in $ExpiredKeys) {
        $Cache.Remove($Key)
    }
}

function Test-HostConnectivity {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$IpAddress,
        [hashtable]$Cache = @{}
    )

    $IsActive = $false
    $Hostname = ""
    $OS = ""
    $MacAddress = ""
    $Manufacturer = ""
    $OpenPorts = @()

    try {
        $Ping = [System.Net.NetworkInformation.Ping]::new()
        $Reply = $Ping.Send($IpAddress, $PingTimeoutMs)
        $IsActive = ($Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
        
        if ($IsActive) {
            $Ttl = $Reply.Options.Ttl
            
            try {
                $Hostname = [System.Net.Dns]::GetHostEntry($IpAddress).HostName
            }
            catch {
                $Hostname = "Desconocido"
            }
            
            if ($IsInDomain) {
                $OS = Get-OSFromWMI -IpAddress $IpAddress
            }
            
            if ([string]::IsNullOrEmpty($OS)) {
                $OS = Get-OSFromTTL -Ttl $Ttl
            }
            
            $MacAddress = Get-MacAddress -IpAddress $IpAddress
            if ([string]::IsNullOrEmpty($MacAddress)) {
                $MacAddress = $null
            }
            
            $Manufacturer = Get-ManufacturerFromOUI -MacAddress $MacAddress
            
            if ($PortScanEnabled) {
                $OpenPorts = Get-OpenPorts -IpAddress $IpAddress -Ports $CommonPorts -Timeout $PortScanTimeout -Cache $Cache
            }
        }
        
        $Ping.Dispose()
    }
    catch {
        $IsActive = $false
    }

    return [PSCustomObject]@{
        IP           = $IpAddress
        Status       = if ($IsActive) { "Active" } else { "Inactive" }
        Hostname     = $Hostname
        OS           = $OS
        MacAddress   = $MacAddress
        Manufacturer = $Manufacturer
        OpenPorts    = $OpenPorts
    }
}

# ==============================================================================
# SECCIÓN 3: EJECUCIÓN DEL ESCANEO
# ==============================================================================

# Cargar cache de puertos
Write-Host "Cargando cache de puertos..." -ForegroundColor Yellow
$PortCache = Read-PortCache
Write-Host "Cache cargado: $($PortCache.Count) entradas." -ForegroundColor Green

Write-Host "Generando lista de objetivos..." -ForegroundColor Yellow
$TargetIps = Get-IpRange -Prefix $SubnetPrefix -StartIP $StartIP -EndIP $EndIP
Write-Host "Objetivos generados: $($TargetIps.Count) direcciones." -ForegroundColor Green

$Results = @()
$TotalHosts = $TargetIps.Count

Write-Host "Modo detectado: SECUENCIAL" -ForegroundColor Yellow

# Ejecución secuencial
$Counter = 0
foreach ($Ip in $TargetIps) {
    $Counter++
    
    # Reporte de progreso para UI (JSON)
    if ($EnableProgress -and $ProgressFile) {
        try {
            $ProgressData = @{
                Current    = $Counter
                Total      = $TotalHosts
                Percentage = [math]::Round(($Counter / $TotalHosts) * 100)
                CurrentIP  = $Ip
            }
            $ProgressData | ConvertTo-Json -Depth 2 | Out-File -FilePath $ProgressFile -Encoding UTF8 -Force
        }
        catch { /* Ignorar errores de escritura */ }
    }

    if ($Counter % 10 -eq 0) {
        Write-Progress -Activity "Escaneando red..." -Status "Procesando $Ip" -PercentComplete (($Counter / $TotalHosts) * 100)
    }
    
    $Results += Test-HostConnectivity -IpAddress $Ip -Cache $PortCache
}
Write-Progress -Activity "Escaneando red..." -Completed

# Actualizar cache con resultados nuevos
Write-Host "Actualizando cache de puertos..." -ForegroundColor Yellow
foreach ($Result in $Results) {
    if ($Result.OpenPorts) {
        foreach ($Port in $Result.OpenPorts) {
            Add-PortToCache -Cache $PortCache -IpAddress $Result.IP -PortInfo $Port
        }
    }
}

# Limpiar y guardar cache
Clean-ExpiredCache -Cache $PortCache
Write-PortCache -Cache $PortCache
Write-Host "Cache actualizado y guardado." -ForegroundColor Green

# ==============================================================================
# SECCIÓN 4: PROCESAMIENTO Y EXPORTACIÓN
# ==============================================================================

Write-Host "Procesando resultados..." -ForegroundColor Yellow

$ActiveHosts = $Results | Where-Object { $_.Status -eq "Active" }
$InactiveCount = ($Results | Where-Object { $_.Status -eq "Inactive" }).Count

Write-Host "Reporte de texto deshabilitado. Solo se enviarán datos a la API." -ForegroundColor Gray

# ==============================================================================
# SECCIÓN 5: ENVÍO A API
# ==============================================================================

Write-Host "----------------------------------------------------------------"
Write-Host "RESUMEN DEL ESCANEO" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------"
Write-Host "Total IPs escaneadas : $($Results.Count)"
Write-Host "IPs Activas          : $($ActiveHosts.Count)" -ForegroundColor Green
Write-Host "IPs Inactivas        : $InactiveCount" -ForegroundColor Red
Write-Host "----------------------------------------------------------------"

# Guardar información del escaneo actual
try {
    $CurrentScanTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $CurrentScanTime | Out-File -FilePath $ScanHistoryFile -Encoding UTF8 -Force
}
catch {
    Write-Warning "No se pudo guardar el historial del escaneo"
}

# ==============================================================================
# FUNCIÓN DE ENVÍO A API
# ==============================================================================

Write-Host "[API] Enviando datos a la API..." -ForegroundColor Cyan

# Preparar datos para la API
$ApiPayload = @{
    Devices = @()
}

foreach ($HostObj in $ActiveHosts) {
    # Convertir puertos a array de objetos
    $OpenPortsArray = @()
    if ($HostObj.OpenPorts) {
        foreach ($Port in $HostObj.OpenPorts) {
            $OpenPortsArray += @{
                port     = $Port.Port
                protocol = $Port.Protocol
                category = $Port.Category
            }
        }
    }
    
    $ApiPayload.Devices += @{
        IP        = $HostObj.IP
        MAC       = if ($HostObj.MacAddress) { $HostObj.MacAddress } else { "" }
        Hostname  = $HostObj.Hostname
        OpenPorts = $OpenPortsArray
    }
}

# Convertir a JSON
$JsonPayload = $ApiPayload | ConvertTo-Json -Depth 10

# Intentar enviar a la API
$ApiSuccess = $false

if ($ApiEnabled) {
    for ($attempt = 1; $attempt -le $ApiRetries; $attempt++) {
        try {
            if ($attempt -gt 1) {
                Write-Host "   Reintento $attempt de $ApiRetries..." -ForegroundColor Yellow
                Start-Sleep -Seconds $ApiRetryDelay
            }
            
            $Response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $JsonPayload -ContentType "application/json" -TimeoutSec $ApiTimeout -ErrorAction Stop
            
            if ($Response.success) {
                Write-Host "[OK] Datos enviados correctamente a la API." -ForegroundColor Green
                Write-Host "   Procesados: $($Response.summary.processed) | Conflictos: $($Response.summary.conflicts) | Errores: $($Response.summary.errors)" -ForegroundColor Gray
                $ApiSuccess = $true
                break
            }
            else {
                Write-Warning "[ADVERTENCIA] La API respondio con error: $($Response.message)"
            }
        }
        catch {
            $ErrorMsg = $_.Exception.Message
            if ($attempt -eq $ApiRetries) {
                Write-Warning "[ERROR] Error al enviar datos a la API despues de $ApiRetries intentos: $ErrorMsg"
            }
            else {
                Write-Host "   Error: $ErrorMsg" -ForegroundColor DarkYellow
            }
        }
    }
}

# Si falló la API, guardar archivo local
if (-not $ApiSuccess) {
    Write-Host "[LOCAL] Guardando resultados locales..." -ForegroundColor Yellow
    
    # Crear formato para cron_process.php
    $LocalPayload = @{
        subnet         = "${SubnetPrefix}0/24"
        scan_timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
        hosts          = @()
    }
    
    foreach ($HostObj in $ActiveHosts) {
        $OpenPortsArray = @()
        if ($HostObj.OpenPorts) {
            foreach ($Port in $HostObj.OpenPorts) {
                $OpenPortsArray += @{
                    port        = $Port.Port
                    protocol    = $Port.Protocol
                    category    = $Port.Category
                    detected_at = $Port.DetectedAt
                }
            }
        }
        
        $LocalPayload.hosts += @{
            ip           = $HostObj.IP
            mac          = $HostObj.MacAddress
            hostname     = $HostObj.Hostname
            os           = $HostObj.OS
            manufacturer = $HostObj.Manufacturer
            open_ports   = $OpenPortsArray
        }
    }
    
    try {
        $LocalJsonPayload = $LocalPayload | ConvertTo-Json -Depth 10
        $LocalJsonPayload | Out-File -FilePath $ScanResultsFile -Encoding UTF8 -Force
        Write-Host "[OK] Archivo $ScanResultsFile generado correctamente." -ForegroundColor Green
    }
    catch {
        Write-Warning "[ERROR] Error al guardar archivo local: $_"
    }
}

Write-Host "================================================================"
Write-Host "ESCANEO COMPLETADO" -ForegroundColor Green
Write-Host "================================================================"