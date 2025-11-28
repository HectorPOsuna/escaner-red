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

# Configuración de Ping
$PingCount = 1
$PingTimeoutMs = 200 # Timeout en milisegundos (ajustar según latencia de red)

# Detección de Dominio (para estrategia híbrida de OS detection)
try {
    $IsInDomain = (Get-WmiObject Win32_ComputerSystem).PartOfDomain
} catch {
    $IsInDomain = $false
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   INICIANDO ESCÁNER DE RED - MONITOR DE PROTOCOLOS" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host "Subred objetivo: ${SubnetPrefix}0/24"
Write-Host "Version de PowerShell: $($PSVersionTable.PSVersion.ToString())"
Write-Host "En dominio: $(if ($IsInDomain) { 'Sí (usando WMI/CIM + TTL)' } else { 'No (usando solo TTL)' })"
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

function Test-HostConnectivity {
    <#
    .SYNOPSIS
        Prueba la conectividad a una IP específica de forma silenciosa.
    .INPUTS
        IpAddress (String)
    .OUTPUTS
        PSCustomObject { IP, Status, Hostname, OS, MacAddress, Manufacturer }
    #>
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$IpAddress
    )

    $IsActive = $false
    $Hostname = ""
    $OS = ""
    $MacAddress = ""
    $Manufacturer = ""

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
        $InDomain = $using:IsInDomain
        $Active = $false
        $HostName = ""
        $OSDetected = ""
        $MacAddr = ""
        $Manuf = ""
        
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
