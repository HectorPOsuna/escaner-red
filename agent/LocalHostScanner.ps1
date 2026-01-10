param (
    [string]$ConfigFile = "config.ps1"
)

# ==============================================================================
# ESCÁNER DE HOST LOCAL (EMBEBIDO)
# ==============================================================================
# Escanea SOLO la máquina local utilizando APIs del SO en lugar de red.
# Recolecta: Hostname, OS, IP, MAC, Puertos Activos.
# ==============================================================================

# Configuración
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptRoot $ConfigFile

# Cargar config si existe
if (Test-Path $ConfigPath) {
    . $ConfigPath
} else {
    Write-Host "Config file not found, using defaults."
    $ApiUrl = "http://localhost/escaner-red/server/api/receive.php"
}

# --- RECOLECCIÓN DE DATOS ---

Write-Host "Recolectando información del sistema..."

# 1. Hostname
$Hostname = [System.Net.Dns]::GetHostName()

# 2. Sistema Operativo (Detallado)
$OSInfo = Get-CimInstance Win32_OperatingSystem
$OSName = $OSInfo.Caption.Trim()
$OSVersion = $OSInfo.Version

# 3. Interfaces de Red (IP y MAC)
# Priorizamos Ethernet y Wi-Fi que tengan Gateway (Internet/Red activa)
$ActiveInterface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

if ($ActiveInterface) {
    $MacAddress = $ActiveInterface.MacAddress -replace "-", ":"
    $IPConfig = Get-NetIPAddress -InterfaceIndex $ActiveInterface.InterfaceIndex -AddressFamily IPv4
    $IPAddress = $IPConfig.IPAddress
} else {
    # Fallback
    $IPAddress = "127.0.0.1"
    $MacAddress = $null
}

# 4. Puertos Activos (TCP/UDP)
Write-Host "Detectando puertos abiertos..."

$OpenPorts = @()
$DetectedPorts = @{}

# Mapeo básico de protocolos comunes (similar al script original pero simplificado)
$CommonProtocols = @{
    21="FTP"; 22="SSH"; 23="Telnet"; 25="SMTP"; 53="DNS"; 80="HTTP"; 
    110="POP3"; 135="RPC"; 139="NetBIOS"; 143="IMAP"; 443="HTTPS"; 
    445="SMB"; 1433="MSSQL"; 3306="MySQL"; 3389="RDP"; 5432="PostgreSQL";
    8080="HTTP-Proxy"; 8443="HTTPS-Alt"
}

# Obtener TCP Listening
$TcpPorts = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
foreach ($conn in $TcpPorts) {
    $p = $conn.LocalPort
    if (-not $DetectedPorts.ContainsKey($p)) {
        $DetectedPorts[$p] = $true
        $proto = if ($CommonProtocols.ContainsKey([int]$p)) { $CommonProtocols[[int]$p] } else { "TCP" }
        $OpenPorts += @{ port = [int]$p; protocol = $proto; type = "TCP" }
    }
}

# Obtener UDP Listeners (Opcional, a veces genera ruido, pero útil para DNS/DHCP)
$UdpPorts = Get-NetUDPEndpoint -ErrorAction SilentlyContinue
foreach ($conn in $UdpPorts) {
    $p = $conn.LocalPort
    # Filtrar puertos efímeros altos si es necesario, o incluir todos
    if ($p -lt 49152) { 
        if (-not $DetectedPorts.ContainsKey($p)) {
            $DetectedPorts[$p] = $true
            $proto = if ($CommonProtocols.ContainsKey([int]$p)) { $CommonProtocols[[int]$p] } else { "UDP" }
            $OpenPorts += @{ port = [int]$p; protocol = $proto; type = "UDP" }
        }
    }
}

Write-Host "Puertos detectados: $($OpenPorts.Count)"

# --- GENERAR PAYLOAD ---

$Payload = @{
    Devices = @(
        @{
            Hostname = $Hostname
            IP = $IPAddress
            MAC = $MacAddress
            OS = $OSName # Detección precisa local
            OS_Simple = "Windows"
            TTL = 128
            OS_Hints = "LocalAgent"
            OpenPorts = $OpenPorts
        }
    )
}

$JsonPayload = $Payload | ConvertTo-Json -Depth 5

# --- ENVIAR A API ---

Write-Host "Enviando datos a: $ApiUrl"

try {
    $Response = Invoke-RestMethod -Uri $ApiUrl -Method Post -Body $JsonPayload -ContentType "application/json" -TimeoutSec 15
    Write-Host "Respuesta API: $($Response.message)" -ForegroundColor Green
    
    # Guardar resultado localmente para debug
    $JsonPayload | Out-File (Join-Path $ScriptRoot "scan_results.json") -Encoding utf8
} catch {
    Write-Host "Error enviando datos: $_" -ForegroundColor Red
    # Guardar error log
    "$(Get-Date) - Error: $_" | Out-File (Join-Path $ScriptRoot "error.log") -Append
}
