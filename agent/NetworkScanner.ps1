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
$OutputFileReport = Join-Path -Path $PSScriptRoot -ChildPath "reporte_de_red.txt"
$ScanHistoryFile = Join-Path -Path $PSScriptRoot -ChildPath "ultimo_escaneo.txt"

# Configuración de Ping
$PingCount = 1
$PingTimeoutMs = 200 # Timeout en milisegundos (ajustar según latencia de red)

# Configuración de Escaneo de Puertos
$PortScanEnabled = $true
$PortScanTimeout = 500 # Timeout en milisegundos por puerto

# Lista de puertos por defecto (Fallback)
$DefaultCommonPorts = @(
    @{Port=21; Protocol="FTP"},
    @{Port=22; Protocol="SSH"},
    @{Port=23; Protocol="Telnet"},
    @{Port=25; Protocol="SMTP"},
    @{Port=53; Protocol="DNS"},
    @{Port=80; Protocol="HTTP"},
    @{Port=110; Protocol="POP3"},
    @{Port=143; Protocol="IMAP"},
    @{Port=443; Protocol="HTTPS"},
    @{Port=445; Protocol="SMB"},
    @{Port=3306; Protocol="MySQL"},
    @{Port=3389; Protocol="RDP"},
    @{Port=5432; Protocol="PostgreSQL"},
    @{Port=8080; Protocol="HTTP-Alt"}
)

$CommonPorts = $DefaultCommonPorts

# Configuración de Caché de Puertos
$PortCacheFile = Join-Path -Path $PSScriptRoot -ChildPath "port_scan_cache.json"
$PortCacheTTLMinutes = 10

# Configuración de API Backend
$EnableApiExport = $true
$ApiUrl = "http://localhost:3000/api/scan-results" # URL por defecto, ajustable
$ApiKey = "" # Opcional, para futura autenticación

# Detección de Dominio (para estrategia híbrida de OS detection)
try {
    $IsInDomain = (Get-WmiObject Win32_ComputerSystem).PartOfDomain
} catch {
    $IsInDomain = $false
}

# Leer información del último escaneo
$LastScanInfo = ""
if (Test-Path $ScanHistoryFile) {
    try {
        $LastScanInfo = Get-Content $ScanHistoryFile -Raw -ErrorAction SilentlyContinue
    } catch {
        $LastScanInfo = "No disponible"
    }
} else {
    $LastScanInfo = "Primer escaneo"
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   INICIANDO ESCÁNER DE RED - MONITOR DE PROTOCOLOS" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host "Subred objetivo: ${SubnetPrefix}0/24"
Write-Host "Version de PowerShell: $($PSVersionTable.PSVersion.ToString())"
Write-Host "En dominio: $(if ($IsInDomain) { 'Sí (usando WMI/CIM + TTL)' } else { 'No (usando solo TTL)' })"
Write-Host "Último escaneo: $LastScanInfo" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------"

# ==============================================================================
# SECCIÓN 2: FUNCIONES AUXILIARES
# ==============================================================================

function Start-BackendServices {
    <#
    .SYNOPSIS
        Inicia los servicios de backend (Node.js) si no están corriendo.
    #>
    $Port = 3000
    $ServerPath = Join-Path -Path $PSScriptRoot -ChildPath "..\server\app.js"
    $ServerDir = Join-Path -Path $PSScriptRoot -ChildPath "..\server"
    
    # Verificar si el puerto está en uso
    $PortInUse = $false
    try {
        $TcpConnection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        if ($TcpConnection) { $PortInUse = $true }
    } catch {
        # Fallback para versiones antiguas de PS
        $PortInUse = $false
    }

    if (-not $PortInUse) {
        Write-Host "Iniciando servidor backend en segundo plano..." -ForegroundColor Cyan
        
        # Intentar encontrar node.exe
        $NodeExe = "node"
        if (Test-Path "C:\Program Files\nodejs\node.exe") {
            $NodeExe = "C:\Program Files\nodejs\node.exe"
        }
        
        try {
            # Iniciar proceso de forma silenciosa
            $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
            $ProcessInfo.FileName = $NodeExe
            $ProcessInfo.Arguments = "app.js"
            $ProcessInfo.WorkingDirectory = $ServerDir
            $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            $ProcessInfo.CreateNoWindow = $true
            $ProcessInfo.UseShellExecute = $true
            
            [System.Diagnostics.Process]::Start($ProcessInfo) | Out-Null
            
            # Esperar un momento para que inicie
            Start-Sleep -Seconds 3
            
            # Verificar nuevamente si inició
            try {
                $TcpConnection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
                if ($TcpConnection) {
                    Write-Host "Servidor iniciado correctamente." -ForegroundColor Green
                    return $true
                }
            } catch {}
            
            Write-Warning "El servidor parece no haber iniciado correctamente."
            return $false
        } catch {
            Write-Warning "No se pudo iniciar el servidor backend automáticamente. Modo Offline activado."
            return $false
        }
    } else {
        # Write-Host "Servidor backend ya está corriendo." -ForegroundColor DarkGray
        return $true
    }
}

# Iniciar servicios y determinar modo
$BackendOnline = Start-BackendServices

if (-not $BackendOnline) {
    Write-Host "⚠️  MODO OFFLINE ACTIVADO: No hay conexión con el backend." -ForegroundColor Yellow
    Write-Host "    Los resultados se guardarán solo localmente en archivos de texto." -ForegroundColor Gray
    $EnableApiExport = $false
} else {
    $EnableApiExport = $true
}

function Get-RemoteProtocols {
    <#
    .SYNOPSIS
        Obtiene la lista de protocolos desde la API del backend.
    #>
    if (-not $EnableApiExport) { return $null }
    
    $ProtocolsUrl = $ApiUrl.Replace("/scan-results", "/protocolos")
    
    try {
        Write-Host "Sincronizando base de datos de protocolos..." -ForegroundColor Cyan
        $Response = Invoke-RestMethod -Uri $ProtocolsUrl -Method Get -ErrorAction Stop -TimeoutSec 5
        
        $RemotePorts = @()
        foreach ($Item in $Response) {
            $RemotePorts += @{
                Port = [int]$Item.port
                Protocol = $Item.protocol
            }
        }
        
        if ($RemotePorts.Count -gt 0) {
            Write-Host "✅ Sincronizados $($RemotePorts.Count) protocolos desde el backend." -ForegroundColor Green
            return $RemotePorts
        }
    } catch {
        Write-Warning "No se pudo sincronizar protocolos desde la API. Usando base de datos local."
        # Write-Warning $_.Exception.Message
    }
    return $null
}

# Intentar actualizar la lista de puertos comunes desde la API
$RemotePortsList = Get-RemoteProtocols
if ($RemotePortsList) {
    # Filtramos para no tener una lista de 6000 puertos si no es necesario, 
    # o podemos usar todos. Para rendimiento, quizás sea mejor usar los Top 100 o 1000.
    # Por ahora, usaremos todos los que vengan (si el usuario quiere escanear todo).
    # Pero OJO: Escanear 6000 puertos por host tardará mucho.
    # Mantenemos la lógica de escaneo rápido, pero actualizamos la DEFINICIÓN.
    
    # Si queremos escanear SOLO los comunes, mantenemos la lista corta.
    # Si queremos que el escáner use la DB para identificar, necesitamos separar
    # "Puertos a Escanear" de "Diccionario de Protocolos".
    
    # Asumiremos que $CommonPorts define QUÉ escanear.
    # Si la API devuelve 6000, escanear 6000 puertos x 254 hosts = LENTO.
    # Estrategia: Usar la lista remota SOLO si son puertos "comunes" o si el usuario lo pide.
    # Por seguridad, mantendremos la lista por defecto para el escaneo activo, 
    # pero podríamos ampliarla si la API devuelve una lista curada de "Top Ports".
    
    # Dado que la tabla tiene TODOS (6000+), no podemos asignarlo directo a $CommonPorts 
    # sin matar el rendimiento.
    # Solución: Mantenemos $CommonPorts como está (o un Top 20 extendido), 
    # pero usamos la API para *identificar* (ya lo hace el backend).
    
    # El usuario pidió: "que use la que esta en la nube".
    # Interpretación: El agente debe saber qué escanear basado en la nube.
    # Si la nube devuelve 6000, el agente escanea 6000? Probablemente no sea lo deseado por defecto.
    
    # Haremos un compromiso: Actualizaremos $CommonPorts con los puertos que la API marque como "esencial", "base_de_datos", "correo", etc.
    # (Necesitaríamos que el endpoint devuelva la categoría).
    
    # Por ahora, para cumplir la solicitud literalmente sin romper el script:
    # Asignaremos los primeros 50 o 100 puertos de la lista remota a $CommonPorts.
    
    $CommonPorts = $RemotePortsList | Select-Object -First 50
    Write-Host "Lista de escaneo actualizada con los Top 50 protocolos de la nube." -ForegroundColor Gray
}

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

function Get-OSFromTTL {
    <#
    .SYNOPSIS
        Infiere el sistema operativo basándose en el valor TTL del ping.
    .PARAMETER Ttl
        Valor TTL obtenido de la respuesta ping.
    .OUTPUTS
        String con el OS inferido.
    #>
    param (
        [int]$Ttl
    )
    
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
    <#
    .SYNOPSIS
        Obtiene el sistema operativo mediante WMI/CIM.
    .PARAMETER IpAddress
        Dirección IP del host a consultar.
    .OUTPUTS
        String con el nombre del OS o cadena vacía si falla.
    #>
    param (
        [string]$IpAddress
    )
    
    try {
        # Intentar consulta CIM (más moderna que WMI)
        $CimSession = New-CimSession -ComputerName $IpAddress -ErrorAction Stop -OperationTimeoutSec 2
        $OS = Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem -ErrorAction Stop
        Remove-CimSession -CimSession $CimSession -ErrorAction SilentlyContinue
        
        if ($OS.Caption) {
            return $OS.Caption -replace 'Microsoft ', ''
        }
    }
    catch {
        # Si falla CIM, retornar vacío para usar TTL como fallback
        return ""
    }
    
    return ""
}

function Get-MacAddress {
    <#
    .SYNOPSIS
        Obtiene la dirección MAC desde la tabla ARP.
    .PARAMETER IpAddress
        Dirección IP del host a consultar.
    .OUTPUTS
        String con la dirección MAC o cadena vacía si no se encuentra.
    #>
    param (
        [string]$IpAddress
    )
    
    try {
        # Intentar usar Get-NetNeighbor (PowerShell 5.1+)
        if (Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue) {
            $Neighbor = Get-NetNeighbor -IPAddress $IpAddress -ErrorAction SilentlyContinue
            if ($Neighbor -and $Neighbor.LinkLayerAddress) {
                return $Neighbor.LinkLayerAddress
            }
        }
        
        # Fallback: parsear salida de arp -a
        $ArpOutput = arp -a $IpAddress 2>$null
        if ($ArpOutput) {
            foreach ($Line in $ArpOutput) {
                if ($Line -match $IpAddress) {
                    # Extraer MAC address (formato xx-xx-xx-xx-xx-xx)
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
    <#
    .SYNOPSIS
        Obtiene el fabricante del dispositivo basándose en el OUI de la MAC.
    .PARAMETER MacAddress
        Dirección MAC del dispositivo.
    .OUTPUTS
        String con el nombre del fabricante o "Desconocido" si no se encuentra.
    #>
    param (
        [string]$MacAddress
    )
    
    # La resolución de fabricantes ahora se maneja en el backend
    return "Desconocido"
}


function Get-OpenPorts {
    <#
    .SYNOPSIS
        Escanea puertos comunes en un host y retorna los que están abiertos.
    .PARAMETER IpAddress
        Dirección IP del host a escanear.
    .PARAMETER Ports
        Array de hashtables con Port y Protocol.
    .PARAMETER Timeout
        Timeout en milisegundos para cada puerto.
    .PARAMETER Cache
        Hashtable con el caché de puertos.
    .OUTPUTS
        Array de objetos con Port, Protocol, Status, DetectedAt.
    #>
    param (
        [string]$IpAddress,
        [array]$Ports,
        [int]$Timeout = 500,
        [hashtable]$Cache = @{}
    )
    
    $OpenPorts = @()
    
    foreach ($PortInfo in $Ports) {
        # Verificar si el puerto está en caché y es válido
        $CachedPort = Test-PortInCache -Cache $Cache -IpAddress $IpAddress -Port $PortInfo.Port
        
        if ($CachedPort) {
            # Usar resultado del caché
            $OpenPorts += $CachedPort
            continue
        }
        
        # No está en caché o expiró, escanear
        try {
            $TestResult = Test-NetConnection -ComputerName $IpAddress -Port $PortInfo.Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -InformationLevel Quiet
            
            if ($TestResult) {
                $PortResult = [PSCustomObject]@{
                    Port = $PortInfo.Port
                    Protocol = $PortInfo.Protocol
                    Status = "Open"
                    DetectedAt = Get-Date -Format "HH:mm:ss"
                }
                $OpenPorts += $PortResult
                
                # Agregar al caché
                Add-PortToCache -Cache $Cache -IpAddress $IpAddress -PortInfo $PortResult
            }
        }
        catch {
            # Si hay error, el puerto está cerrado o filtrado
            continue
        }
    }
    
    return $OpenPorts
}

# ==============================================================================
# FUNCIONES DE CACHÉ DE PUERTOS
# ==============================================================================

function Read-PortCache {
    <#
    .SYNOPSIS
        Lee el caché de puertos desde el archivo JSON.
    .OUTPUTS
        Hashtable con el caché de puertos.
    #>
    if (Test-Path $PortCacheFile) {
        try {
            $JsonContent = Get-Content $PortCacheFile -Raw -ErrorAction Stop
            $CacheData = $JsonContent | ConvertFrom-Json
            
            # Convertir a hashtable para acceso rápido
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
    <#
    .SYNOPSIS
        Guarda el caché de puertos en el archivo JSON.
    .PARAMETER Cache
        Hashtable con el caché de puertos.
    #>
    param (
        [hashtable]$Cache
    )
    
    try {
        $Cache | ConvertTo-Json -Depth 3 | Out-File -FilePath $PortCacheFile -Encoding UTF8 -Force
    }
    catch {
        Write-Warning "No se pudo guardar el caché de puertos: $_"
    }
}

function Test-PortInCache {
    <#
    .SYNOPSIS
        Verifica si un puerto está en caché y aún es válido.
    .PARAMETER Cache
        Hashtable con el caché.
    .PARAMETER IpAddress
        Dirección IP.
    .PARAMETER Port
        Número de puerto.
    .OUTPUTS
        PSCustomObject con la información del puerto si está en caché y es válido, $null si no.
    #>
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
            # Entrada válida, retornar datos
            return [PSCustomObject]@{
                Port = $Entry.Port
                Protocol = $Entry.Protocol
                Status = $Entry.Status
                DetectedAt = $Entry.DetectedAt
            }
        }
    }
    
    return $null
}

function Add-PortToCache {
    <#
    .SYNOPSIS
        Agrega un puerto al caché.
    .PARAMETER Cache
        Hashtable con el caché.
    .PARAMETER IpAddress
        Dirección IP.
    .PARAMETER PortInfo
        Objeto con información del puerto.
    #>
    param (
        [hashtable]$Cache,
        [string]$IpAddress,
        [PSCustomObject]$PortInfo
    )
    
    $Key = "${IpAddress}:$($PortInfo.Port)"
    
    $Cache[$Key] = @{
        IP = $IpAddress
        Port = $PortInfo.Port
        Protocol = $PortInfo.Protocol
        Status = $PortInfo.Status
        LastScanned = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        DetectedAt = $PortInfo.DetectedAt
    }
}

function Clean-ExpiredCache {
    <#
    .SYNOPSIS
        Limpia entradas expiradas del caché.
    .PARAMETER Cache
        Hashtable con el caché.
    #>
    param (
        [hashtable]$Cache
    )
    
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

function Send-ResultsToApi {
    <#
    .SYNOPSIS
        Envía los resultados del escaneo a la API backend.
    .PARAMETER Results
        Array de objetos con los resultados del escaneo.
    .PARAMETER Subnet
        Subred escaneada.
    #>
    param (
        [array]$Results,
        [string]$Subnet
    )
    
    if (-not $EnableApiExport) {
        return
    }
    
    Write-Host "Preparando envío de datos a la API..." -ForegroundColor Yellow
    
    # Filtrar solo hosts activos y formatear para JSON
    $ActiveHosts = $Results | Where-Object { $_.Status -eq "Active" }
    
    if ($ActiveHosts.Count -eq 0) {
        Write-Host "No hay hosts activos para enviar." -ForegroundColor Yellow
        return
    }
    
    $HostsPayload = @()
    
    foreach ($HostObj in $ActiveHosts) {
        $OpenPortsList = @()
        if ($HostObj.OpenPorts) {
            foreach ($Port in $HostObj.OpenPorts) {
                $OpenPortsList += @{
                    port = $Port.Port
                    protocol = $Port.Protocol
                    detected_at = $Port.DetectedAt
                }
            }
        }
        
        $HostsPayload += @{
            ip = $HostObj.IP
            mac = $HostObj.MacAddress
            hostname = $HostObj.Hostname
            manufacturer = $HostObj.Manufacturer
            os = $HostObj.OS
            open_ports = $OpenPortsList
        }
    }
    
    $Payload = @{
        scan_timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        subnet = "${Subnet}0/24"
        hosts = $HostsPayload
    }
    
    try {
        $JsonPayload = $Payload | ConvertTo-Json -Depth 10
        
        Write-Host "Enviando $($HostsPayload.Count) hosts a $ApiUrl..." -ForegroundColor Cyan
        
        $Response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $JsonPayload -ContentType "application/json" -ErrorAction Stop
        
        Write-Host "✅ Datos enviados correctamente a la API." -ForegroundColor Green
    }
    catch {
        Write-Warning "❌ Error al enviar datos a la API: $($_.Exception.Message)"
        # No detenemos el script, solo notificamos el error de envío
    }
}

function Test-HostConnectivity {
    <#
    .SYNOPSIS
        Prueba la conectividad a una IP específica de forma silenciosa.
    .INPUTS
        IpAddress (String)
    .OUTPUTS
        PSCustomObject { IP, Status, Hostname, OS, MacAddress, Manufacturer, OpenPorts }
    #>
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
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
        # Usar clase .NET Ping para mayor control sobre el Timeout (ms) y mejor rendimiento
        # Esto soluciona el problema de la variable $PingTimeoutMs no utilizada
        $Ping = [System.Net.NetworkInformation.Ping]::new()
        $Reply = $Ping.Send($IpAddress, $PingTimeoutMs)
        $IsActive = ($Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
        
        # Si el host está activo, intentar resolver el hostname y OS
        if ($IsActive) {
            # Capturar TTL para detección de OS
            $Ttl = $Reply.Options.Ttl
            
            # Resolver hostname
            try {
                $Hostname = [System.Net.Dns]::GetHostEntry($IpAddress).HostName
            }
            catch {
                # Si no se puede resolver, usar valor por defecto
                $Hostname = "Desconocido"
            }
            
            # Detección híbrida de OS
            if ($IsInDomain) {
                # Intentar WMI/CIM primero si estamos en dominio
                $OS = Get-OSFromWMI -IpAddress $IpAddress
            }
            
            # Si no obtuvimos OS por WMI o no estamos en dominio, usar TTL
            if ([string]::IsNullOrEmpty($OS)) {
                $OS = Get-OSFromTTL -Ttl $Ttl
            }
            
            # Obtener dirección MAC desde ARP
            $MacAddress = Get-MacAddress -IpAddress $IpAddress
            if ([string]::IsNullOrEmpty($MacAddress)) {
                $MacAddress = "No disponible"
            }
            
            # Obtener fabricante desde OUI
            $Manufacturer = Get-ManufacturerFromOUI -MacAddress $MacAddress
            
            # Escanear puertos si está habilitado
            if ($PortScanEnabled) {
                $OpenPorts = Get-OpenPorts -IpAddress $IpAddress -Ports $CommonPorts -Timeout $PortScanTimeout -Cache $Cache
            }
        }
        
        $Ping.Dispose()
    }
    catch {
        # En caso de error de ejecución (no de ping fallido), asumimos inactivo
        $IsActive = $false
    }

    return [PSCustomObject]@{
        IP = $IpAddress
        Status = if ($IsActive) { "Active" } else { "Inactive" }
        Hostname = $Hostname
        OS = $OS
        MacAddress = $MacAddress
        Manufacturer = $Manufacturer
        OpenPorts = $OpenPorts
    }
}

# ==============================================================================
# SECCIÓN 3: EJECUCIÓN DEL ESCANEO
# ==============================================================================

# Cargar caché de puertos
Write-Host "Cargando caché de puertos..." -ForegroundColor Yellow
$PortCache = Read-PortCache
Write-Host "Caché cargado: $($PortCache.Count) entradas." -ForegroundColor Green

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
        $InDomain = $using:IsInDomain
        $PortsToScan = $using:CommonPorts
        $PortTimeout = $using:PortScanTimeout
        $ScanPorts = $using:PortScanEnabled
        $Cache = $using:PortCache
        $TTL = $using:PortCacheTTLMinutes
        $Active = $false
        $HostName = ""
        $OSDetected = ""
        $MacAddr = ""
        $Manuf = ""
        $Ports = @()
        
        try {
            $Ping = [System.Net.NetworkInformation.Ping]::new()
            $Reply = $Ping.Send($Ip, $Timeout)
            $Active = ($Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
            
            # Si el host está activo, intentar resolver el hostname y OS
            if ($Active) {
                # Capturar TTL para detección de OS
                $Ttl = $Reply.Options.Ttl
                
                # Resolver hostname
                try {
                    $HostName = [System.Net.Dns]::GetHostEntry($Ip).HostName
                }
                catch {
                    # Si no se puede resolver, usar valor por defecto
                    $HostName = "Desconocido"
                }
                
                # Detección híbrida de OS
                if ($InDomain) {
                    # Intentar WMI/CIM primero si estamos en dominio
                    try {
                        $CimSession = New-CimSession -ComputerName $Ip -ErrorAction Stop -OperationTimeoutSec 2
                        $OS = Get-CimInstance -CimSession $CimSession -ClassName Win32_OperatingSystem -ErrorAction Stop
                        Remove-CimSession -CimSession $CimSession -ErrorAction SilentlyContinue
                        
                        if ($OS.Caption) {
                            $OSDetected = $OS.Caption -replace 'Microsoft ', ''
                        }
                    }
                    catch {
                        # Si falla CIM, usar TTL como fallback
                        $OSDetected = ""
                    }
                }
                
                # Si no obtuvimos OS por WMI o no estamos en dominio, usar TTL
                if ([string]::IsNullOrEmpty($OSDetected)) {
                    # Inferir OS desde TTL
                    if ($Ttl -le 64) {
                        $OSDetected = "Linux/Unix"
                    }
                    elseif ($Ttl -le 128) {
                        $OSDetected = "Windows"
                    }
                    elseif ($Ttl -le 255) {
                        $OSDetected = "Cisco/Network Device"
                    }
                    else {
                        $OSDetected = "Unknown"
                    }
                }
                
                # Obtener dirección MAC desde ARP
                if ([string]::IsNullOrEmpty($MacAddr)) {
                    $ArpOutput = arp -a $Ip 2>$null
                    if ($ArpOutput) {
                        foreach ($Line in $ArpOutput) {
                            if ($Line -match $Ip) {
                                if ($Line -match '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})') {
                                    $MacAddr = $Matches[0]
                                    break
                                }
                            }
                        }
                    }
                }
                
                if ([string]::IsNullOrEmpty($MacAddr)) {
                    $MacAddr = "No disponible"
                }
                
                # Obtener fabricante desde OUI
                $Manuf = "Desconocido"
                
                # Escanear puertos si está habilitado
                if ($ScanPorts) {
                    foreach ($PortInfo in $PortsToScan) {
                        # Verificar caché (lógica inline para paralelismo)
                        $Key = "${Ip}:${PortInfo.Port}"
                        $Cached = $false
                        
                        if ($Cache.ContainsKey($Key)) {
                            $Entry = $Cache[$Key]
                            $LastScanned = [DateTime]::Parse($Entry.LastScanned)
                            $Age = (Get-Date) - $LastScanned
                            
                            if ($Age.TotalMinutes -lt $TTL) {
                                $Ports += [PSCustomObject]@{
                                    Port = $Entry.Port
                                    Protocol = $Entry.Protocol
                                    Status = $Entry.Status
                                    DetectedAt = $Entry.DetectedAt
                                }
                                $Cached = $true
                            }
                        }
                        
                        if (-not $Cached) {
                            try {
                                $TestResult = Test-NetConnection -ComputerName $Ip -Port $PortInfo.Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -InformationLevel Quiet
                                if ($TestResult) {
                                    $Ports += [PSCustomObject]@{
                                        Port = $PortInfo.Port
                                        Protocol = $PortInfo.Protocol
                                        Status = "Open"
                                        DetectedAt = Get-Date -Format "HH:mm:ss"
                                    }
                                }
                            } catch {
                                continue
                            }
                        }
                    }
                }
            }
            
            $Ping.Dispose()
        } catch { 
            $Active = $false 
        }
        
        # Devolver objeto al hilo principal
        [PSCustomObject]@{
            IP = $Ip
            Status = if ($Active) { "Active" } else { "Inactive" }
            Hostname = $HostName
            OS = $OSDetected
            MacAddress = $MacAddr
            Manufacturer = $Manuf
            OpenPorts = $Ports
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
        
        $Results += Test-HostConnectivity -IpAddress $Ip -Cache $PortCache
    }
    Write-Progress -Activity "Escaneando red..." -Completed
}

# Actualizar caché con resultados nuevos
Write-Host "Actualizando caché de puertos..." -ForegroundColor Yellow
foreach ($Result in $Results) {
    if ($Result.OpenPorts) {
        foreach ($Port in $Result.OpenPorts) {
            Add-PortToCache -Cache $PortCache -IpAddress $Result.IP -PortInfo $Port
        }
    }
}

# Limpiar y guardar caché
Clean-ExpiredCache -Cache $PortCache
Write-PortCache -Cache $PortCache
Write-Host "Caché actualizado y guardado." -ForegroundColor Green

# ==============================================================================
# SECCIÓN 4: PROCESAMIENTO Y EXPORTACIÓN
# ==============================================================================

Write-Host "Procesando resultados..." -ForegroundColor Yellow

# Filtrar solo hosts activos
$ActiveHosts = $Results | Where-Object { $_.Status -eq "Active" }
$InactiveCount = ($Results | Where-Object { $_.Status -eq "Inactive" }).Count

# Generar reporte consolidado
try {
    # Crear contenido del reporte
    $ReportContent = @()
    
    # Encabezado del reporte
    $ReportContent += "================================================================"
    $ReportContent += "   REPORTE DE ESCANEO DE RED - MONITOR DE PROTOCOLOS"
    $ReportContent += "================================================================"
    $ReportContent += "Fecha y Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $ReportContent += "Subred escaneada: ${SubnetPrefix}0/24"
    $ReportContent += "Total de IPs escaneadas: $($Results.Count)"
    $ReportContent += "Hosts activos encontrados: $($ActiveHosts.Count)"
    $ReportContent += "Hosts inactivos: $InactiveCount"
    $ReportContent += "================================================================"
    $ReportContent += ""
    
    if ($ActiveHosts.Count -gt 0) {
        $ReportContent += "HOSTS ACTIVOS DETECTADOS:"
        $ReportContent += "----------------------------------------------------------------"
        $ReportContent += ""
        
        foreach ($ActiveHost in $ActiveHosts) {
            $ReportContent += "IP: $($ActiveHost.IP)"
            $ReportContent += "Hostname: $($ActiveHost.Hostname)"
            $ReportContent += "OS: $($ActiveHost.OS)"
            $ReportContent += "MAC Address: $($ActiveHost.MacAddress)"
            $ReportContent += "Fabricante: $($ActiveHost.Manufacturer)"
            
            # Agregar información de puertos con formato mejorado
            if ($ActiveHost.OpenPorts -and $ActiveHost.OpenPorts.Count -gt 0) {
                $ReportContent += "Puertos Abiertos: $($ActiveHost.OpenPorts.Count) puerto(s) detectado(s)"
                $ReportContent += ""
                $ReportContent += "  Lista de Puertos y Protocolos:"
                $ReportContent += "  ----------------------------------------"
                foreach ($Port in $ActiveHost.OpenPorts) {
                    $ReportContent += "  Puerto: $($Port.Port) | Protocolo: $($Port.Protocol) | Hora: $($Port.DetectedAt)"
                }
                $ReportContent += "  ----------------------------------------"
            } else {
                $ReportContent += "Puertos Abiertos: Ninguno detectado"
            }
            
            $ReportContent += ""
        }
    }
    else {
        $ReportContent += "No se encontraron hosts activos en la red."
        $ReportContent += ""
    }
    
    $ReportContent += "================================================================"
    $ReportContent += "Fin del reporte"
    $ReportContent += "================================================================"
    
    # Exportar reporte
    $ReportContent | Out-File -FilePath $OutputFileReport -Encoding UTF8 -Force
    
    Write-Host "Reporte generado correctamente." -ForegroundColor Green
}
catch {
    Write-Error "Error al generar reporte: $_"
}

# ==============================================================================
# SECCIÓN 5: RESUMEN FINAL
# ==============================================================================

Write-Host "----------------------------------------------------------------"
Write-Host "RESUMEN DEL ESCANEO" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------"
Write-Host "Total IPs escaneadas : $($Results.Count)"
Write-Host "IPs Activas          : $($ActiveHosts.Count)" -ForegroundColor Green
Write-Host "IPs Inactivas        : $InactiveCount" -ForegroundColor Red
Write-Host "----------------------------------------------------------------"
Write-Host "Archivo generado:"
Write-Host " -> $OutputFileReport"
Write-Host "================================================================"

# Guardar información del escaneo actual para futuras referencias
try {
    $CurrentScanTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $CurrentScanTime | Out-File -FilePath $ScanHistoryFile -Encoding UTF8 -Force
} catch {
    Write-Warning "No se pudo guardar el historial del escaneo"
}

# Enviar resultados a la API
Send-ResultsToApi -Results $Results -Subnet $SubnetPrefix
