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
$CommonPorts = @(
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

# Configuración de Caché de Puertos
$PortCacheFile = Join-Path -Path $PSScriptRoot -ChildPath "port_scan_cache.json"
$PortCacheTTLMinutes = 10

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
    
    if ([string]::IsNullOrEmpty($MacAddress) -or $MacAddress -eq "No disponible") {
        return "Desconocido"
    }
    
    # Extraer los primeros 3 octetos (OUI) y normalizar
    $OUI = $MacAddress -replace '[:-]', '' | Select-Object -First 6
    $OUI = $OUI.ToUpper().Substring(0, [Math]::Min(6, $OUI.Length))
    
    # Base de datos de OUI embebida (fabricantes comunes)
    $OUIDatabase = @{
        # Cisco
        "00000C" = "Cisco Systems"
        "000142" = "Cisco Systems"
        "000163" = "Cisco Systems"
        "0001C7" = "Cisco Systems"
        "0050F2" = "Cisco Systems"
        "001CBF" = "Cisco Systems"
        
        # Intel
        "0003FF" = "Intel Corporation"
        "001517" = "Intel Corporation"
        "001B21" = "Intel Corporation"
        "7054D2" = "Intel Corporation"
        "D4BED9" = "Intel Corporation"
        
        # Apple
        "000393" = "Apple, Inc."
        "000A27" = "Apple, Inc."
        "000A95" = "Apple, Inc."
        "001451" = "Apple, Inc."
        "0016CB" = "Apple, Inc."
        "001EC2" = "Apple, Inc."
        "0050E4" = "Apple, Inc."
        "A4C361" = "Apple, Inc."
        
        # Dell
        "000874" = "Dell Inc."
        "000BDB" = "Dell Inc."
        "000D56" = "Dell Inc."
        "000F1F" = "Dell Inc."
        "001372" = "Dell Inc."
        "0015C5" = "Dell Inc."
        "B8CA3A" = "Dell Inc."
        
        # HP/Hewlett Packard
        "000805" = "HP"
        "001279" = "HP"
        "001438" = "HP"
        "001560" = "HP"
        "001E0B" = "HP"
        "002264" = "HP"
        "D89EF3" = "HP"
        
        # Realtek
        "00E04C" = "Realtek Semiconductor"
        "525400" = "Realtek Semiconductor"
        "E03F49" = "Realtek Semiconductor"
        
        # TP-Link
        "001D0F" = "TP-Link Technologies"
        "0C8268" = "TP-Link Technologies"
        "1C61B4" = "TP-Link Technologies"
        "50C7BF" = "TP-Link Technologies"
        "A42BB0" = "TP-Link Technologies"
        
        # D-Link
        "000D88" = "D-Link Corporation"
        "001346" = "D-Link Corporation"
        "001B11" = "D-Link Corporation"
        "0022B0" = "D-Link Corporation"
        "C8D3A3" = "D-Link Corporation"
        
        # Netgear
        "000FB5" = "Netgear"
        "001B2F" = "Netgear"
        "001E2A" = "Netgear"
        "002275" = "Netgear"
        "A040A0" = "Netgear"
        
        # VMware
        "005056" = "VMware, Inc."
        "000C29" = "VMware, Inc."
        "000569" = "VMware, Inc."
        
        # Microsoft
        "000D3A" = "Microsoft Corporation"
        "001DD8" = "Microsoft Corporation"
        "7C1E52" = "Microsoft Corporation"
        
        # Samsung
        "0012FB" = "Samsung Electronics"
        "001377" = "Samsung Electronics"
        "0015B9" = "Samsung Electronics"
        "001D25" = "Samsung Electronics"
        "E8508B" = "Samsung Electronics"
        
        # Huawei
        "000E0C" = "Huawei Technologies"
        "001E10" = "Huawei Technologies"
        "0025BC" = "Huawei Technologies"
        "F8E71E" = "Huawei Technologies"
        
        # Xiaomi
        "64B473" = "Xiaomi Communications"
        "F8A45F" = "Xiaomi Communications"
        "34CE00" = "Xiaomi Communications"
    }
    
    # Buscar en la base de datos
    if ($OUIDatabase.ContainsKey($OUI)) {
        return $OUIDatabase[$OUI]
    }
    
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
                try {
                    if (Get-Command Get-NetNeighbor -ErrorAction SilentlyContinue) {
                        $Neighbor = Get-NetNeighbor -IPAddress $Ip -ErrorAction SilentlyContinue
                        if ($Neighbor -and $Neighbor.LinkLayerAddress) {
                            $MacAddr = $Neighbor.LinkLayerAddress
                        }
                    }
                    
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
                }
                catch {
                    $MacAddr = ""
                }
                
                if ([string]::IsNullOrEmpty($MacAddr)) {
                    $MacAddr = "No disponible"
                }
                
                # Obtener fabricante desde OUI
                if ([string]::IsNullOrEmpty($MacAddr) -or $MacAddr -eq "No disponible") {
                    $Manuf = "Desconocido"
                } else {
                    # Extraer OUI y buscar fabricante
                    $OUI = $MacAddr -replace '[:-]', ''
                    $OUI = $OUI.ToUpper().Substring(0, [Math]::Min(6, $OUI.Length))
                    
                    # Base de datos OUI (mismo que en Get-ManufacturerFromOUI)
                    $OUIDb = @{
                        "00000C"="Cisco Systems";"000142"="Cisco Systems";"000163"="Cisco Systems";"0001C7"="Cisco Systems";"0050F2"="Cisco Systems";"001CBF"="Cisco Systems"
                        "0003FF"="Intel Corporation";"001517"="Intel Corporation";"001B21"="Intel Corporation";"7054D2"="Intel Corporation";"D4BED9"="Intel Corporation"
                        "000393"="Apple, Inc.";"000A27"="Apple, Inc.";"000A95"="Apple, Inc.";"001451"="Apple, Inc.";"0016CB"="Apple, Inc.";"001EC2"="Apple, Inc.";"0050E4"="Apple, Inc.";"A4C361"="Apple, Inc."
                        "000874"="Dell Inc.";"000BDB"="Dell Inc.";"000D56"="Dell Inc.";"000F1F"="Dell Inc.";"001372"="Dell Inc.";"0015C5"="Dell Inc.";"B8CA3A"="Dell Inc."
                        "000805"="HP";"001279"="HP";"001438"="HP";"001560"="HP";"001E0B"="HP";"002264"="HP";"D89EF3"="HP"
                        "00E04C"="Realtek Semiconductor";"525400"="Realtek Semiconductor";"E03F49"="Realtek Semiconductor"
                        "001D0F"="TP-Link Technologies";"0C8268"="TP-Link Technologies";"1C61B4"="TP-Link Technologies";"50C7BF"="TP-Link Technologies";"A42BB0"="TP-Link Technologies"
                        "000D88"="D-Link Corporation";"001346"="D-Link Corporation";"001B11"="D-Link Corporation";"0022B0"="D-Link Corporation";"C8D3A3"="D-Link Corporation"
                        "000FB5"="Netgear";"001B2F"="Netgear";"001E2A"="Netgear";"002275"="Netgear";"A040A0"="Netgear"
                        "005056"="VMware, Inc.";"000C29"="VMware, Inc.";"000569"="VMware, Inc."
                        "000D3A"="Microsoft Corporation";"001DD8"="Microsoft Corporation";"7C1E52"="Microsoft Corporation"
                        "0012FB"="Samsung Electronics";"001377"="Samsung Electronics";"0015B9"="Samsung Electronics";"001D25"="Samsung Electronics";"E8508B"="Samsung Electronics"
                        "000E0C"="Huawei Technologies";"001E10"="Huawei Technologies";"0025BC"="Huawei Technologies";"F8E71E"="Huawei Technologies"
                        "64B473"="Xiaomi Communications";"F8A45F"="Xiaomi Communications";"34CE00"="Xiaomi Communications"
                    }
                    
                    if ($OUIDb.ContainsKey($OUI)) {
                        $Manuf = $OUIDb[$OUI]
                    } else {
                        $Manuf = "Desconocido"
                    }
                }
                
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
