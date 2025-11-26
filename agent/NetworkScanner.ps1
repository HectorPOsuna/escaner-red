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

function Test-HostConnectivity {
    <#
    .SYNOPSIS
        Prueba la conectividad a una IP específica de forma silenciosa.
    .INPUTS
        IpAddress (String)
    .OUTPUTS
        PSCustomObject { IP, Status, Hostname, OS, MacAddress }
    #>
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$IpAddress
    )

    $IsActive = $false
    $Hostname = ""
    $OS = ""
    $MacAddress = ""

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
