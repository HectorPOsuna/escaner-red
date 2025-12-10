param (
    [string]$ConfigFile = "config.ps1"
)

<#
.SYNOPSIS
    Agente de Monitoreo de Red - Escáner Inteligente con Clasificación por Prioridad
    
.DESCRIPTION
    Este script escanea una subred identificando IPs activas y puertos abiertos.
    
.NOTES
    Versión: 2.0.2 (Patched/Safe)
    Autor: Monitor de Actividad de Protocolos de Red Team
    Fecha: Diciembre 2025
    Requiere: PowerShell 5.1+
#>

# ==============================================================================
# SECCIÓN 1: CONFIGURACIÓN Y VERIFICACIÓN INICIAL
# ==============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   ESCÁNER DE RED INTELIGENTE - INICIANDO" -ForegroundColor Cyan
Write-Host "================================================================"

# Cargar configuración
if (Test-Path $ConfigFile) {
    $ConfigPath = Convert-Path $ConfigFile
    Write-Host "[CONFIG] Cargando configuración desde: $ConfigPath" -ForegroundColor Green
    . $ConfigPath
}
else {
    Write-Host "[ERROR] Archivo de configuración no encontrado: $ConfigFile" -ForegroundColor Red
    Write-Host "[INFO] Creando configuración por defecto..." -ForegroundColor Yellow
    
    # Configuración por defecto
    $OperationMode = "hybrid"
    $ApiEnabled = $true
    $ApiUrl = "https://dsantana.fimaz.uas.edu.mx/lisi3309/server/api/receive.php"
    $ApiTimeout = 10
    $ApiRetries = 3
    $ApiRetryDelay = 2
    $SubnetPrefix = "192.168.1."
    $PortScanEnabled = $true
    $PortScanTimeout = 500
    $PortCacheTTLMinutes = 10
    $ScanResultsFile = "scan_results.json"
    $PhpProcessorScript = "..\server\api\receive.php"
    $PhpExecutable = "php"
    $EnableLogging = $true
    $LogFile = "scanner.log"
}

# Configurar rutas
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ScanResultsFile = Join-Path -Path $ScriptRoot -ChildPath $ScanResultsFile
$PortCacheFile = Join-Path -Path $ScriptRoot -ChildPath "port_scan_cache.json"
$ScanHistoryFile = Join-Path -Path $ScriptRoot -ChildPath "ultimo_escaneo.txt"

# Configuración de ping (Aumentado para mejor detección en Wi-Fi)
$PingTimeoutMs = 1000

# Función de Rotación de Logs
function Rotate-Logs {
    param($LogPath, $MaxSizeMB = 5, $MaxBackups = 5)
    
    if (Test-Path $LogPath) {
        $file = Get-Item $LogPath
        if ($file.Length -gt ($MaxSizeMB * 1MB)) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupPath = "$LogPath.$timestamp.bak"
            Rename-Item -Path $LogPath -NewName $backupPath
            
            # Limpiar backups viejos
            $backups = Get-ChildItem -Path "$LogPath.*.bak" | Sort-Object LastWriteTime
            if ($backups.Count -gt $MaxBackups) {
                $backups[0..($backups.Count - $MaxBackups - 1)] | Remove-Item
            }
        }
    }
}

# Ejecutar rotación si log existe
if ($EnableLogging) {
    $FullLogPath = Join-Path $ScriptRoot $LogFile
    Rotate-Logs -LogPath $FullLogPath
}

# Prioridades de categorías (menor número = mayor prioridad)
$PortPriorities = @{
    "esencial" = 1
    "seguro" = 2
    "correo" = 3
    "base_de_datos" = 4
    "gestion" = 5
    "remoto" = 6
    "monitoreo" = 7
    "archivos" = 8
    "multimedia" = 9
    "inseguro" = 10
    "precaucion" = 11
    "juegos" = 12
    "desarrollo" = 13
    "virtualizacion" = 14
    "impresion" = 15
    "backup" = 16
    "voz_ip" = 17
    "inusual" = 18
    "reservado" = 19
}

# Lista completa de puertos por categoría
$CommonPorts = @(
    @{Port = 53; Protocol = "DNS"; Category = "esencial"; Priority = 1 },
    @{Port = 67; Protocol = "DHCP"; Category = "esencial"; Priority = 1 },
    @{Port = 68; Protocol = "DHCP"; Category = "esencial"; Priority = 1 },
    @{Port = 123; Protocol = "NTP"; Category = "esencial"; Priority = 1 },
    @{Port = 161; Protocol = "SNMP"; Category = "esencial"; Priority = 1 },
    @{Port = 162; Protocol = "SNMP-Trap"; Category = "esencial"; Priority = 1 },
    @{Port = 5353; Protocol = "mDNS"; Category = "esencial"; Priority = 1 },
    
    @{Port = 22; Protocol = "SSH"; Category = "seguro"; Priority = 2 },
    @{Port = 443; Protocol = "HTTPS"; Category = "seguro"; Priority = 2 },
    @{Port = 993; Protocol = "IMAPS"; Category = "seguro"; Priority = 2 },
    @{Port = 995; Protocol = "POP3S"; Category = "seguro"; Priority = 2 },
    @{Port = 465; Protocol = "SMTPS"; Category = "seguro"; Priority = 2 },
    @{Port = 8443; Protocol = "HTTPS-Alt"; Category = "seguro"; Priority = 2 },
    @{Port = 636; Protocol = "LDAPS"; Category = "seguro"; Priority = 2 },
    
    @{Port = 25; Protocol = "SMTP"; Category = "correo"; Priority = 3 },
    @{Port = 110; Protocol = "POP3"; Category = "correo"; Priority = 3 },
    @{Port = 143; Protocol = "IMAP"; Category = "correo"; Priority = 3 },
    @{Port = 587; Protocol = "SMTP-Submission"; Category = "correo"; Priority = 3 },
    
    @{Port = 3306; Protocol = "MySQL"; Category = "base_de_datos"; Priority = 4 },
    @{Port = 5432; Protocol = "PostgreSQL"; Category = "base_de_datos"; Priority = 4 },
    @{Port = 1433; Protocol = "MSSQL"; Category = "base_de_datos"; Priority = 4 },
    @{Port = 1521; Protocol = "Oracle"; Category = "base_de_datos"; Priority = 4 },
    @{Port = 27017; Protocol = "MongoDB"; Category = "base_de_datos"; Priority = 4 },
    @{Port = 6379; Protocol = "Redis"; Category = "base_de_datos"; Priority = 4 },
    @{Port = 9200; Protocol = "Elasticsearch"; Category = "base_de_datos"; Priority = 4 },
    
    @{Port = 9090; Protocol = "Prometheus"; Category = "gestion"; Priority = 5 },
    @{Port = 9100; Protocol = "Node-Exporter"; Category = "gestion"; Priority = 5 },
    @{Port = 3000; Protocol = "Grafana"; Category = "gestion"; Priority = 5 },
    @{Port = 8080; Protocol = "HTTP-Proxy"; Category = "gestion"; Priority = 5 },
    
    @{Port = 3389; Protocol = "RDP"; Category = "remoto"; Priority = 6 },
    @{Port = 5900; Protocol = "VNC"; Category = "remoto"; Priority = 6 },
    @{Port = 5800; Protocol = "VNC-HTTP"; Category = "remoto"; Priority = 6 },
    @{Port = 23; Protocol = "Telnet"; Category = "remoto"; Priority = 6 },
    
    @{Port = 21; Protocol = "FTP"; Category = "archivos"; Priority = 8 },
    @{Port = 69; Protocol = "TFTP"; Category = "archivos"; Priority = 8 },
    @{Port = 445; Protocol = "SMB"; Category = "archivos"; Priority = 8 },
    @{Port = 2049; Protocol = "NFS"; Category = "archivos"; Priority = 8 },
    @{Port = 873; Protocol = "Rsync"; Category = "archivos"; Priority = 8 },
    
    @{Port = 80; Protocol = "HTTP"; Category = "inseguro"; Priority = 10 },
    @{Port = 135; Protocol = "MSRPC"; Category = "inseguro"; Priority = 10 },
    @{Port = 137; Protocol = "NetBIOS"; Category = "inseguro"; Priority = 10 },
    @{Port = 139; Protocol = "NetBIOS"; Category = "inseguro"; Priority = 10 },
    
    @{Port = 5000; Protocol = "Flask"; Category = "desarrollo"; Priority = 13 },
    @{Port = 8000; Protocol = "Django"; Category = "desarrollo"; Priority = 13 },
    @{Port = 8081; Protocol = "Dev-Server"; Category = "desarrollo"; Priority = 13 },
    
    @{Port = 6667; Protocol = "IRC"; Category = "inusual"; Priority = 18 },
    @{Port = 6697; Protocol = "IRC-SSL"; Category = "inusual"; Priority = 18 },
    @{Port = 19132; Protocol = "Minecraft-PE"; Category = "inusual"; Priority = 18 },
    @{Port = 25565; Protocol = "Minecraft"; Category = "inusual"; Priority = 18 },
    @{Port = 27015; Protocol = "Steam"; Category = "inusual"; Priority = 18 }
) | Sort-Object -Property Priority

# ==============================================================================
# SECCIÓN 3: FUNCIONES DE SOPORTE
# ==============================================================================

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "[CONFIG] Modo operación: $OperationMode" -ForegroundColor Magenta
    Write-Host "[CONFIG] Subred: ${SubnetPrefix}0/24" -ForegroundColor Cyan
    Write-Host "[CONFIG] Puertos a escanear: $($CommonPorts.Count)" -ForegroundColor Cyan
    if ($ApiEnabled) {
        Write-Host "[CONFIG] API habilitada: $ApiUrl" -ForegroundColor Green
    }
}

# ==============================================================================
# SECCIÓN 2: VERIFICACIÓN DE API
# ==============================================================================

$ApiAvailable = $false
$ApiResponse = $null

function Test-ApiConnection {
    param([string]$Url, [int]$Timeout = 5)
    
    Write-Host "[API] Probando conexión con API..." -ForegroundColor Cyan
    
    try {
        # Probar conexión básica
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Timeout = $Timeout * 1000
        $request.Method = "GET"
        $request.UserAgent = "NetworkScanner/2.0"
        
        $response = $request.GetResponse()
        $statusCode = $response.StatusCode
        $response.Close()
        
        Write-Host "[API] API respondió con código: $statusCode" -ForegroundColor Green
        return $true
        
    } catch [System.Net.WebException] {
        if ($_.Exception.Response -ne $null) {
            $resp = $_.Exception.Response
            $statusCode = $resp.StatusCode.value__
            Write-Host "[API] API respondió con error: $statusCode" -ForegroundColor Yellow
            # Si responde con error, al menos está activa
            return $true
        } elseif ($_.Exception.Status -eq [System.Net.WebExceptionStatus]::Timeout) {
            Write-Host "[API] Timeout al conectar con la API" -ForegroundColor Red
            return $false
        } else {
            Write-Host "[API] Error de conexión: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "[API] Error inesperado: $_" -ForegroundColor Red
        return $false
    }
}

# Verificar API si se está ejecutando el script (no importando)
if ($MyInvocation.InvocationName -ne '.') {
    # Verificar API según modo de operación
    if ($OperationMode -eq "api" -or $OperationMode -eq "hybrid") {
        if ($ApiEnabled) {
            Write-Host "[API] Verificando disponibilidad de API..." -ForegroundColor Yellow
            $ApiAvailable = Test-ApiConnection -Url $ApiUrl -Timeout 5
            
            if (-not $ApiAvailable) {
                Write-Host "[API] API no disponible." -ForegroundColor Red
                if ($OperationMode -eq "hybrid") {
                    Write-Host "[MODO] Cambiando a modo local (fallback)" -ForegroundColor Yellow
                    $OperationMode = "local"
                }
            } else {
                Write-Host "[API] API disponible. Preparando envío de datos." -ForegroundColor Green
            }
        } else {
             Write-Host "[API] API deshabilitada en configuración." -ForegroundColor Yellow
             $OperationMode = "local"
        }
    }
}

# ==============================================================================
# SECCIÓN 3: FUNCIONES DE ESCANEO
# ==============================================================================

function Get-IpRange {
    param([string]$Prefix)
    
    $ips = @()
    for ($i = 1; $i -lt 255; $i++) {
        $ips += "${Prefix}${i}"
    }
    return $ips
}

function Test-HostAlive {
    param([string]$IpAddress)
    
    return Test-Connection -ComputerName $IpAddress -Count 1 -Quiet -BufferSize 16
}

function Get-HostInfo {
    param([string]$IpAddress)
    
    $info = @{
        Hostname = "Desconocido"
        OS = "Unknown"
        MAC = ""
        Manufacturer = "Desconocido"
    }
    
    try {
        # Obtener hostname
        try {
            $info.Hostname = [System.Net.Dns]::GetHostEntry($IpAddress).HostName
        } catch { }
        
        # Obtener MAC desde ARP
        try {
            $arpOutput = arp -a $IpAddress 2>$null
            foreach ($line in $arpOutput) {
                if ($line -match $IpAddress) {
                    if ($line -match '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})') {
                        $info.MAC = $Matches[0]
                        break
                    }
                }
            }
        } catch { }
        
        # Detectar OS por TTL
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send($IpAddress, $PingTimeoutMs)
        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            $ttl = $reply.Options.Ttl
            if ($ttl -le 64) { $info.OS = "Linux/Unix" }
            elseif ($ttl -le 128) { $info.OS = "Windows" }
            else { $info.OS = "Network Device" }
        }
        
    } catch {
        # FIX: Usar ${} para interpolación segura de variables
        Write-Debug "Error obteniendo informacion de ${IpAddress}: $_"
    }
    
    return $info
}

function Read-PortCache {
    if (Test-Path $PortCacheFile) {
        try {
            $json = Get-Content $PortCacheFile -Raw | ConvertFrom-Json
            $cache = @{}
            $json.PSObject.Properties | ForEach-Object {
                $cache[$_.Name] = $_.Value
            }
            return $cache
        } catch {
            return @{}
        }
    }
    return @{}
}

function Write-PortCache {
    param([hashtable]$Cache)
    
    try {
        $Cache | ConvertTo-Json -Depth 3 | Out-File $PortCacheFile -Force
    } catch {
        Write-Warning "Error guardando caché: $_"
    }
}

function Test-PortInCache {
    param([hashtable]$Cache, [string]$Ip, [int]$Port)
    
    $key = "${Ip}:${Port}"
    if ($Cache.ContainsKey($key)) {
        $entry = $Cache[$key]
        $age = (Get-Date) - [DateTime]::Parse($entry.LastScanned)
        if ($age.TotalMinutes -lt $PortCacheTTLMinutes) {
            return [PSCustomObject]@{
                Port = $entry.Port
                Protocol = $entry.Protocol
                Category = $entry.Category
                Status = $entry.Status
                DetectedAt = $entry.DetectedAt
            }
        }
    }
    return $null
}

function Add-ToCache {
    param([hashtable]$Cache, [string]$Ip, $PortInfo)
    
    $key = "${Ip}:$($PortInfo.Port)"
    $Cache[$key] = @{
        Port = $PortInfo.Port
        Protocol = $PortInfo.Protocol
        Category = $PortInfo.Category
        Status = $PortInfo.Status
        LastScanned = (Get-Date).ToString("o")
        DetectedAt = $PortInfo.DetectedAt
    }
}

function Test-Port {
    param([string]$Ip, [int]$Port, [int]$Timeout = 500)
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($Ip, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($Timeout, $false)
        
        if ($wait) {
            $tcpClient.EndConnect($asyncResult) | Out-Null
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    } catch {
        return $false
    }
}

function Scan-PortsByPriority {
    param([string]$Ip, [array]$Ports, [hashtable]$Cache)
    
    $openPorts = @()
    
    # Agrupar por prioridad
    $priorityGroups = @{}
    foreach ($port in $Ports) {
        $pri = $port.Priority
        if (-not $priorityGroups.ContainsKey($pri)) {
            $priorityGroups[$pri] = @()
        }
        $priorityGroups[$pri] += $port
    }
    
    # Escanear por prioridad (de menor a mayor)
    $priorities = $priorityGroups.Keys | Sort-Object
    
    Write-Host "  Escaneando $Ip por prioridad..." -ForegroundColor DarkGray
    
    foreach ($priority in $priorities) {
        $groupPorts = $priorityGroups[$priority]
        $category = $groupPorts[0].Category
        
        Write-Host "    Prioridad $priority ($category): $($groupPorts.Count) puertos" -ForegroundColor DarkGray
        
        foreach ($portInfo in $groupPorts) {
            # Verificar caché primero
            $cached = Test-PortInCache -Cache $Cache -Ip $Ip -Port $portInfo.Port
            if ($cached) {
                $openPorts += $cached
                continue
            }
            
            # Escanear puerto
            if (Test-Port -Ip $Ip -Port $portInfo.Port -Timeout $PortScanTimeout) {
                $result = [PSCustomObject]@{
                    Port = $portInfo.Port
                    Protocol = $portInfo.Protocol
                    Category = $portInfo.Category
                    Status = "Open"
                    DetectedAt = (Get-Date).ToString("HH:mm:ss")
                    Priority = $portInfo.Priority
                }
                
                $openPorts += $result
                Add-ToCache -Cache $Cache -Ip $Ip -PortInfo $result
                
                # Mostrar feedback para puertos importantes
                if ($portInfo.Category -eq "esencial") {
                    Write-Host "      [+] $($portInfo.Port)/$($portInfo.Protocol) - ESENCIAL" -ForegroundColor Green
                }
                if ($portInfo.Category -eq "seguro") {
                    Write-Host "      [+] $($portInfo.Port)/$($portInfo.Protocol) - SEGURO" -ForegroundColor DarkGreen
                }
            }
        }
    }
    
    return $openPorts
}

# ==============================================================================
# SECCIÓN 4: ESCANEO PRINCIPAL
# ==============================================================================

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host "INICIANDO ESCANEO DE RED" -ForegroundColor Cyan
    Write-Host "================================================================"

    # Cargar caché
    $portCache = Read-PortCache
    Write-Host "[CACHE] Cargadas $($portCache.Count) entradas" -ForegroundColor Gray

    # Asegurar que prefix tenga valor
    if ([string]::IsNullOrEmpty($SubnetPrefix)) {
        $SubnetPrefix = "192.168.1."
        Write-Warning "SubnetPrefix no detectado. Usando defecto: $SubnetPrefix"
    }

# Generar IPs a escanear
$targetIps = Get-IpRange -Prefix $SubnetPrefix
Write-Host "[OBJETIVOS] $($targetIps.Count) IPs a escanear" -ForegroundColor Yellow

$results = @()
$counter = 0
$totalIps = $targetIps.Count

foreach ($ip in $targetIps) {
    $counter++
    $percent = [math]::Round(($counter / $totalIps) * 100)
    
    Write-Progress -Activity "Escaneando red" -Status "$ip ($counter/$totalIps)" -PercentComplete $percent
    
    Write-Host "[$counter/$totalIps] Probando $ip..." -ForegroundColor DarkGray
    
    # Verificar si el host está vivo
    if (Test-HostAlive -IpAddress $ip) {
        Write-Host "  [+] ACTIVA" -ForegroundColor Green
        
        # Obtener información del host
        $hostInfo = Get-HostInfo -IpAddress $ip
        
        # Escanear puertos (si está habilitado)
        $openPorts = @()
        if ($PortScanEnabled) {
            $openPorts = Scan-PortsByPriority -Ip $ip -Ports $CommonPorts -Cache $portCache
            Write-Host "  Puertos abiertos: $($openPorts.Count)" -ForegroundColor Cyan
        }
        
        # Agregar a resultados
        $results += [PSCustomObject]@{
            IP = $ip
            Status = "Active"
            Hostname = $hostInfo.Hostname
            OS = $hostInfo.OS
            MAC = $hostInfo.MAC
            Manufacturer = $hostInfo.Manufacturer
            OpenPorts = $openPorts
            ScanTime = Get-Date
        }
        
    } else {
        Write-Host "  [-] INACTIVA" -ForegroundColor Red
        $results += [PSCustomObject]@{
            IP = $ip
            Status = "Inactive"
            Hostname = ""
            OS = ""
            MAC = ""
            Manufacturer = ""
            OpenPorts = @()
            ScanTime = Get-Date
        }
    }
}

Write-Progress -Completed

# Guardar caché actualizado
Write-PortCache -Cache $portCache
Write-Host "[CACHE] Cache actualizada y guardada" -ForegroundColor Green

# ==============================================================================
# SECCIÓN 5: PROCESAMIENTO DE RESULTADOS
# ==============================================================================

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "PROCESANDO RESULTADOS" -ForegroundColor Cyan
Write-Host "================================================================"

$activeHosts = $results | Where-Object { $_.Status -eq "Active" }
$inactiveHosts = $results | Where-Object { $_.Status -eq "Inactive" }

Write-Host "ESTADISTICAS GENERALES:" -ForegroundColor Yellow
Write-Host "   Total IPs escaneadas: $totalIps" -ForegroundColor White
Write-Host "   IPs activas: $($activeHosts.Count)" -ForegroundColor Green
Write-Host "   IPs inactivas: $($inactiveHosts.Count)" -ForegroundColor Red

# Estadísticas de puertos
$portStats = @{}
$totalOpenPorts = 0

foreach ($host in $activeHosts) {
    foreach ($port in $host.OpenPorts) {
        $totalOpenPorts++
        $cat = $port.Category
        $portStats[$cat] = ($portStats[$cat] + 1) -as [int]
    }
}

if ($totalOpenPorts -gt 0) {
    Write-Host "`nESTADISTICAS DE PUERTOS:" -ForegroundColor Yellow
    Write-Host "   Total puertos abiertos: $totalOpenPorts" -ForegroundColor White
    
    # Ordenar por prioridad
    $sortedCats = $portStats.Keys | Sort-Object {
        if ($PortPriorities.ContainsKey($_)) { $PortPriorities[$_] } else { 99 }
    }
    
    foreach ($cat in $sortedCats) {
        $count = $portStats[$cat]
        $percentage = [math]::Round(($count / $totalOpenPorts) * 100, 1)
        $priority = if ($PortPriorities.ContainsKey($cat)) { $PortPriorities[$cat] } else { "N/A" }
        
        $color = switch ($priority) {
            1 { "Green" }
            2 { "DarkGreen" }
            {$_ -ge 10} { "Yellow" }
            default { "White" }
        }
        
        Write-Host "   $cat (Pri: $priority): $count ($percentage%)" -ForegroundColor $color
    }
}

# Guardar historial
$scanTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$scanTime | Out-File $ScanHistoryFile -Force
Write-Host "`nEscaneo guardado: $scanTime" -ForegroundColor Gray

# ==============================================================================
# SECCIÓN 6: ENVÍO A API O GUARDADO LOCAL
# ==============================================================================

function Send-ToApi {
    param([array]$Hosts)
    
    Write-Host "`nENVIANDO DATOS A LA API..." -ForegroundColor Cyan
    Write-Host "   URL: $ApiUrl" -ForegroundColor DarkCyan
    
    # Preparar payload
    $devices = @()
    foreach ($host in $Hosts) {
        $ports = @()
        foreach ($port in $host.OpenPorts) {
            $ports += @{
                port = $port.Port
                protocol = $port.Protocol
                category = $port.Category
                detected_at = $port.DetectedAt
            }
        }
        
        $devices += @{
            IP = $host.IP
            MAC = $host.MAC
            Hostname = $host.Hostname
            OpenPorts = $ports
        }
    }
    
    $payload = @{
        Devices = $devices
        ScanTime = $scanTime
        Subnet = "${SubnetPrefix}0/24"
    }
    
    $json = $payload | ConvertTo-Json -Depth 5
    
    # Enviar a API
    for ($i = 1; $i -le $ApiRetries; $i++) {
        Write-Host "   Intento $i de $ApiRetries..." -ForegroundColor DarkGray
        
        try {
            $response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $json `
                -ContentType "application/json" -TimeoutSec $ApiTimeout
            
            if ($response.success) {
                Write-Host "   DATOS ENVIADOS EXITOSAMENTE" -ForegroundColor Green
                Write-Host "   Procesados: $($response.summary.processed)" -ForegroundColor Gray
                Write-Host "   Conflictos: $($response.summary.conflicts)" -ForegroundColor Gray
                Write-Host "   Errores: $($response.summary.errors)" -ForegroundColor Gray
                return $true
            } else {
                Write-Host "   API respondio con error: $($response.message)" -ForegroundColor Yellow
            }
        } catch {
            if ($i -eq $ApiRetries) {
                Write-Host "   FALLO DESPUES DE $ApiRetries INTENTOS: $($_.Exception.Message)" -ForegroundColor Red
                return $false
            } else {
                Write-Host "   Reintentando en $ApiRetryDelay segundos..." -ForegroundColor Yellow
                Start-Sleep -Seconds $ApiRetryDelay
            }
        }
    }
    
    return $false
}

function Save-Local {
    param([array]$Hosts)
    
    Write-Host "GUARDANDO DATOS LOCALMENTE..." -ForegroundColor Yellow
    
    $localData = @{
        subnet = "${SubnetPrefix}0/24"
        scan_timestamp = $scanTime
        hosts = @()
    }
    
    foreach ($host in $Hosts) {
        $ports = @()
        foreach ($port in $host.OpenPorts) {
            $ports += @{
                port = $port.Port
                protocol = $port.Protocol
                category = $port.Category
                detected_at = $port.DetectedAt
            }
        }
        
        $localData.hosts += @{
            ip = $host.IP
            mac = $host.MAC
            hostname = $host.Hostname
            os = $host.OS
            manufacturer = $host.Manufacturer
            open_ports = $ports
        }
    }
    
    try {
        $localData | ConvertTo-Json -Depth 5 | Out-File $ScanResultsFile -Force
        Write-Host "   ARCHIVO GUARDADO: $ScanResultsFile" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "   ERROR GUARDANDO ARCHIVO: $_" -ForegroundColor Red
        return $false
    }
}

# Ejecutar según modo de operación
$success = $false

switch ($OperationMode) {
    "api" {
        if ($ApiAvailable) {
            $success = Send-ToApi -Hosts $activeHosts
            if (-not $success) {
                Write-Host "   Fallo envio a API, guardando localmente..." -ForegroundColor Yellow
                Save-Local -Hosts $activeHosts
            }
        } else {
            Write-Host "   API no disponible, guardando localmente..." -ForegroundColor Yellow
            Save-Local -Hosts $activeHosts
        }
    }
    
    "hybrid" {
        if ($ApiAvailable) {
            Write-Host "   Modo hibrido: Intentando API primero..." -ForegroundColor Cyan
            $success = Send-ToApi -Hosts $activeHosts
            if (-not $success) {
                Write-Host "   Fallo API, guardando localmente..." -ForegroundColor Yellow
                Save-Local -Hosts $activeHosts
            }
        } else {
            Write-Host "   Modo hibrido: API no disponible, guardando localmente..." -ForegroundColor Yellow
            Save-Local -Hosts $activeHosts
        }
    }
    
    "local" {
        Save-Local -Hosts $activeHosts
    }
    
    default {
        Write-Host "   Modo desconocido, guardando localmente..." -ForegroundColor Yellow
        Save-Local -Hosts $activeHosts
    }
}

# ==============================================================================
# SECCIÓN 7: FINALIZACIÓN
# ==============================================================================

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "ESCANEO COMPLETADO" -ForegroundColor Green
Write-Host "================================================================"

Write-Host "RESUMEN FINAL:" -ForegroundColor Yellow
Write-Host "   - Subred: ${SubnetPrefix}0/24" -ForegroundColor White
Write-Host "   - Hosts activos: $($activeHosts.Count)" -ForegroundColor Green
Write-Host "   - Puertos abiertos: $totalOpenPorts" -ForegroundColor White
Write-Host "   - Modo utilizado: $OperationMode" -ForegroundColor Magenta
Write-Host "   - Tiempo: $scanTime" -ForegroundColor Gray

Write-Host "`nPROCESO TERMINADO" -ForegroundColor Green

# Devolver resultados para posible procesamiento posterior
return $results}
