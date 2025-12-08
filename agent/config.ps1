# ================================================================
# CONFIGURACIÓN DEL AGENTE DE ESCANEO
# ================================================================

# Modo de Operación
# - "local": Procesa localmente con cron_process.php
# - "api": Envía a API remota
# - "hybrid": Intenta API primero, fallback a local
$OperationMode = "hybrid"

# Configuración de API
$ApiEnabled = $true
$ApiUrl = "http://dsantana.fimaz.uas.edu.mx/escaner-red/server/api/receive.php"
$ApiTimeout = 10  # segundos
$ApiRetries = 3
$ApiRetryDelay = 2  # segundos entre reintentos

# Configuración de Subred
$SubnetPrefix = "192.168.100."

# Configuración de Escaneo de Puertos
$PortScanEnabled = $true
$PortScanTimeout = 500  # milisegundos

# Configuración de Caché
$PortCacheTTLMinutes = 10

# Rutas de Archivos
$ScanResultsFile = "scan_results.json"
$PhpProcessorScript = "..\server\cron_process.php"
$PhpExecutable = "php"

# Configuración de Logs
$EnableLogging = $true
$LogFile = "scanner.log"
