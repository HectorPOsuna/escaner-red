<?php
/**
 * API REST Unificada - Monitor de Red
 * 
 * Unificación de:
 * - Conexión DB
 * - Carga de .env
 * - Validación de Payload
 * - Procesamiento de Escaneo
 * - Detección de Conflictos
 * - Logging
 */

// -----------------------------------------------------------------------------
// 0. CONFIGURACIÓN DB COMPARTIDA
// -----------------------------------------------------------------------------
// receive.php está en /lisi3309/server/api/, db_config.php está en /lisi3309/
// Necesitamos subir 2 niveles: ../.. 
require_once __DIR__ . '/../../db_config.php';

// -----------------------------------------------------------------------------
// 1. CONFIGURACIÓN Y HEADERS
// -----------------------------------------------------------------------------

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Manejo de preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Configuración de errores (ocultar errores PHP nativos en respuesta, logearlos)
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// Rutas
$baseDir = __DIR__; // server/api
$rootDir = dirname(dirname($baseDir)); // root del proyecto
$logDir  = $rootDir . '/logs';
$logFile = $logDir . '/api_requests.log';

// -----------------------------------------------------------------------------
// 2. HELPERS (Logging, Env, Response)
// -----------------------------------------------------------------------------

function writeLog($message, $type = 'INFO') {
    global $logFile, $logDir;
    
    // Crear directorio logs si no existe
    if (!file_exists($logDir)) {
        mkdir($logDir, 0755, true);
    }

    // Rotación de logs: si es mayor a 5MB, renombrar a .bak
    if (file_exists($logFile) && filesize($logFile) > 5 * 1024 * 1024) {
        rename($logFile, $logFile . '.' . date('Ymd_His') . '.bak');
        // Mantener solo ultimos 5 logs
        $files = glob($logFile . '.*.bak');
        if (count($files) > 5) {
            usort($files, function($a, $b) { return filemtime($a) - filemtime($b); });
            unlink($files[0]); // Borrar el mas viejo
        }
    }

    $timestamp = date('Y-m-d H:i:s');
    $entry = "[$timestamp] [$type] $message" . PHP_EOL;
    file_put_contents($logFile, $entry, FILE_APPEND);
}

function sendResponse($success, $message, $data = [], $code = 200) {
    http_response_code($code);
    echo json_encode([
        'success' => $success,
        'message' => $message,
        'data' => $data
    ]);
    exit;
}

// Cargar variables de entorno MANUALMENTE
if (!function_exists('loadEnv')) {
function loadEnv($path) {
    if (!file_exists($path)) {
        throw new Exception("Archivo .env no encontrado en: $path");
    }
    
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        
        // Separar clave=valor
        if (strpos($line, '=') !== false) {
            list($name, $value) = explode('=', $line, 2);
            $name = trim($name);
            $value = trim($value);
            // Eliminar comillas si existen
            $value = trim($value, "\"'");
            
            $_ENV[$name] = $value;
        }
    }
}
}

// -----------------------------------------------------------------------------
// 3. CONEXIÓN BASE DE DATOS
// -----------------------------------------------------------------------------

// Helper de DB eliminado, se usa $pdo global de db_config.php
// function getDbConnection() ... eliminado
// -----------------------------------------------------------------------------
// 4. LÓGICA DE VALIDACIÓN
// -----------------------------------------------------------------------------

function validatePayload($data, &$errors) {
    if (!isset($data['Devices']) || !is_array($data['Devices'])) {
        $errors[] = "Campo 'Devices' requerido y debe ser un array";
        return false;
    }

    if (empty($data['Devices'])) {
        $errors[] = "El array 'Devices' no puede estar vacío";
        return false;
    }

    foreach ($data['Devices'] as $index => $device) {
        // Validar IP
        if (empty($device['IP'])) {
            $errors[] = "Dispositivo #$index: IP requerida";
        } elseif (!filter_var($device['IP'], FILTER_VALIDATE_IP)) {
            $errors[] = "Dispositivo #$index: IP inválida '{$device['IP']}'";
        }

        // Validar MAC (si existe)
        if (!empty($device['MAC'])) {
            // Regex simple para MAC: acepta : o -
            if (!preg_match('/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/', $device['MAC'])) {
                $errors[] = "Dispositivo #$index: MAC inválida '{$device['MAC']}'";
            }
        }
    }

    return empty($errors);
}

function normalizePayload($data) {
    $hosts = [];
    
    // Detectar subred básica (simple inferencia)
    $subnet = '0.0.0.0/0';
    if (!empty($data['Devices'][0]['IP'])) {
        $parts = explode('.', $data['Devices'][0]['IP']);
        array_pop($parts);
        $subnet = implode('.', $parts) . '.0/24';
    }

    foreach ($data['Devices'] as $device) {
        $ip = $device['IP'];
        $mac = isset($device['MAC']) ? strtoupper(str_replace('-', ':', $device['MAC'])) : null;
        $hostname = $device['Hostname'] ?? 'Desconocido';
        $openPortsRaw = $device['OpenPorts'] ?? '';
        
        // NUEVOS CAMPOS del escáner mejorado
        $osFromScanner = $device['OS'] ?? 'Unknown';  // OS detallado
        $osSimple = $device['OS_Simple'] ?? 'Unknown'; // OS simple
        $ttl = isset($device['TTL']) ? intval($device['TTL']) : null;
        $osHints = isset($device['OS_Hints']) ? $device['OS_Hints'] : '';
        
        // Parsear puertos (mejorado para manejar array o string)
        $ports = [];
        if (is_array($openPortsRaw)) {
            // Ya viene como array de objetos
            $ports = $openPortsRaw;
        } elseif (is_string($openPortsRaw) && !empty(trim($openPortsRaw))) {
            // Intentar parsear como JSON primero
            $decoded = json_decode($openPortsRaw, true);
            if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
                $ports = $decoded;
            } else {
                // Parsear como string separado por comas
                $parts = explode(',', $openPortsRaw);
                foreach ($parts as $p) {
                    $p = trim($p);
                    if (is_numeric($p)) {
                        $ports[] = ['port' => intval($p), 'protocol' => 'Unknown'];
                    }
                }
            }
        }

        $hosts[] = [
            'ip' => $ip,
            'mac' => $mac,
            'hostname' => $hostname,
            'os' => $osFromScanner,  // Usar el OS detallado del escáner
            'os_simple' => $osSimple,
            'ttl' => $ttl,
            'os_hints' => $osHints,
            'manufacturer' => 'Desconocido', // Será resuelto por OUI después
            'open_ports' => $ports
        ];
    }

    return [
        'scan_timestamp' => date('Y-m-d\TH:i:s'),
        'subnet' => $subnet,
        'hosts' => $hosts
    ];
}


// -----------------------------------------------------------------------------
// 5. CLASE DE PROCESAMIENTO (Micro-ORM Embebido)
// -----------------------------------------------------------------------------

class Processor {
    private $pdo;
    private $stats = ['processed' => 0, 'conflicts' => 0, 'errors' => 0];

    public function __construct($pdo) {
        $this->pdo = $pdo;
    }

    public function process($scanData) {
        foreach ($scanData['hosts'] as $host) {
            try {
                $this->pdo->beginTransaction();

                // 1. Detección de Conflictos
                $this->detectConflicts($host);

                // 2. Persistir Host
                $this->persistHost($host);

                $this->pdo->commit();
                $this->stats['processed']++;
            } catch (Exception $e) {
                $this->pdo->rollBack();
                $this->stats['errors']++;
                writeLog("Error procesando IP {$host['ip']}: " . $e->getMessage(), 'ERROR');
            }
        }
        return $this->stats;
    }

    // --- Lógica de Negocio ---

    private function detectConflicts($host) {
        $ip = $host['ip'];
        $mac = $host['mac'];
        $hostname = $host['hostname'];

        if ($ip) {
            $existing = $this->fetchOne("SELECT * FROM equipos WHERE ip = ?", [$ip]);
            if ($existing) {
                // Conflicto de IP (Misma IP, diferente MAC = posible suplantación o cambio de tarjeta)
                if ($mac && $existing['mac'] && $mac !== $existing['mac']) {
                    $this->registrarConflicto($ip, $mac, $hostname, 
                        "Conflicto de IP: Asignada a {$existing['hostname']} ({$existing['mac']}) pero detectada en $hostname ($mac)");
                }
                // Conflicto de Hostname (Misma IP, diferente Hostname = cambio de nombre o DNS issue)
                elseif ($hostname && $existing['hostname'] && $hostname !== $existing['hostname']) {
                    // Solo si no es el mismo dispositivo (verificado por MAC)
                    if (!$mac || !$existing['mac'] || $mac !== $existing['mac']) {
                         $this->registrarConflicto($ip, $mac, $hostname, 
                        "Conflicto de Hostname: IP $ip cambió de {$existing['hostname']} a $hostname");
                    }
                }
            }
        }

        if ($mac) {
            $existing = $this->fetchOne("SELECT * FROM equipos WHERE mac = ?", [$mac]);
            if ($existing) {
                // Conflicto de MAC (Misma MAC, diferente Hostname = cambio de nombre)
                if ($hostname && $existing['hostname'] && $hostname !== $existing['hostname']) {
                    $this->registrarConflicto($ip, $mac, $hostname, 
                        "Conflicto de MAC: Dispositivo $mac cambió nombre de {$existing['hostname']} a $hostname");
                }
            }
        }
    }

    private function detectAndMapOS($osFromScanner, $hostname, $openPorts, $ttl = null) {
    // Normalizar inputs
    $osFromScanner = strtolower(trim($osFromScanner));
    $hostname = strtolower(trim($hostname));
    
    // Si el escáner ya detectó algo específico, usar eso primero
    if ($osFromScanner !== 'unknown' && $osFromScanner !== 'desconocido') {
        // MAPA DE DETECCIÓN -> NOMBRE EN BD (ampliado)
        $osMapping = [
            // Windows
            'windows' => 'Windows (Generic)',
            'windows (generic)' => 'Windows (Generic)',
            'windows 11' => 'Windows 11',
            'windows 10' => 'Windows 10',
            'windows 8.1' => 'Windows 8.1',
            'windows 8' => 'Windows 8',
            'windows 7' => 'Windows 7',
            'windows vista' => 'Windows Vista',
            'windows xp' => 'Windows XP',
            'windows server' => 'Windows Server',
            'windows (rdp)' => 'Windows',
            'windows (winrm)' => 'Windows',
            'windows (smb)' => 'Windows',
            
            // Linux/Unix
            'linux/unix' => 'Linux/Unix (Generic)',
            'linux/unix (generic)' => 'Linux/Unix (Generic)',
            'linux/unix (ssh)' => 'Linux/Unix (Generic)',
            'ubuntu' => 'Ubuntu',
            'debian' => 'Debian',
            'centos' => 'CentOS',
            'red hat' => 'Red Hat Enterprise Linux',
            'rhel' => 'Red Hat Enterprise Linux',
            'fedora' => 'Fedora',
            'arch linux' => 'Arch Linux',
            'linux mint' => 'Linux Mint',
            'raspberry pi' => 'Raspberry Pi OS',
            'raspbian' => 'Raspberry Pi OS',
            'kali linux' => 'Kali Linux',
            'alpine' => 'Alpine Linux',
            'opensuse' => 'openSUSE',
            'gentoo' => 'Gentoo',
            
            // macOS
            'macos' => 'macOS',
            'mac os' => 'macOS',
            'apple' => 'macOS',
            'apple device' => 'macOS',
            
            // Network Devices
            'network device' => 'Network Device',
            'router' => 'Router',
            'switch' => 'Switch',
            'firewall' => 'Firewall',
            'access point' => 'Access Point',
            'ap' => 'Access Point',
            'printer' => 'Printer',
            'camera' => 'Camera',
            'nas' => 'NAS Device',
            'voip' => 'VoIP Phone',
            'iot' => 'IoT Device',
            
            // Específicos de fabricantes
            'cisco' => 'Cisco IOS',
            'cisco ios' => 'Cisco IOS',
            'mikrotik' => 'MikroTik RouterOS',
            'ubiquiti' => 'Ubiquiti EdgeOS',
            'pfsense' => 'pfSense',
            'opnsense' => 'OPNsense',
            'fortinet' => 'FortiOS',
            'palo alto' => 'Palo Alto PAN-OS',
            
            // Virtualización
            'proxmox' => 'Proxmox VE',
            'vmware' => 'VMware ESXi',
            'hyper-v' => 'Hyper-V',
            'esxi' => 'VMware ESXi',
            
            // Mobile
            'android' => 'Android',
            'ios' => 'iOS',
            'ipados' => 'iPadOS',
            'chrome os' => 'Chrome OS',
            
            // Desconocido
            'unknown' => 'Desconocido',
            'desconocido' => 'Desconocido'
        ];
        
        // 1. Buscar coincidencia exacta en el mapa
        if (isset($osMapping[$osFromScanner])) {
            return $osMapping[$osFromScanner];
        }
        
        // 2. Buscar por patrones en el nombre recibido
        foreach ($osMapping as $key => $value) {
            if (strpos($osFromScanner, $key) !== false) {
                return $value;
            }
        }
    }
    
    // 3. Analizar hostname para inferir (si no se detectó por el escáner)
    $hostnamePatterns = [
        // Windows Server
        '/^dc[0-9]/i' => 'Windows Server',
        '/dc[0-9]/i' => 'Windows Server',
        '/\.dc\./i' => 'Windows Server',
        '/server/i' => 'Windows Server',
        '/srv[0-9]/i' => 'Windows Server',
        '/exchange/i' => 'Windows Server',
        '/sql/i' => 'Windows Server',
        
        // Linux
        '/ubuntu/i' => 'Ubuntu',
        '/debian/i' => 'Debian',
        '/centos/i' => 'CentOS',
        '/rhel/i' => 'Red Hat Enterprise Linux',
        '/fedora/i' => 'Fedora',
        '/arch/i' => 'Arch Linux',
        '/mint/i' => 'Linux Mint',
        '/raspberry/i' => 'Raspberry Pi OS',
        '/rpi/i' => 'Raspberry Pi OS',
        '/kali/i' => 'Kali Linux',
        
        // Dispositivos de red
        '/router/i' => 'Router',
        '/rt-[0-9]/i' => 'Router',
        '/rt[0-9]/i' => 'Router',
        '/switch/i' => 'Switch',
        '/sw-[0-9]/i' => 'Switch',
        '/sw[0-9]/i' => 'Switch',
        '/firewall/i' => 'Firewall',
        '/fw-[0-9]/i' => 'Firewall',
        '/ap-[0-9]/i' => 'Access Point',
        '/ap[0-9]/i' => 'Access Point',
        '/printer/i' => 'Printer',
        '/print/i' => 'Printer',
        '/nas/i' => 'NAS Device',
        '/camera/i' => 'Camera',
        '/cam-[0-9]/i' => 'Camera',
        '/voip/i' => 'VoIP Phone',
        '/phone/i' => 'VoIP Phone',
        
        // Versiones Windows específicas
        '/win11/i' => 'Windows 11',
        '/windows11/i' => 'Windows 11',
        '/win10/i' => 'Windows 10',
        '/windows10/i' => 'Windows 10',
        '/win7/i' => 'Windows 7',
        '/windows7/i' => 'Windows 7',
        '/win8/i' => 'Windows 8',
        '/windows8/i' => 'Windows 8',
    ];
    
    foreach ($hostnamePatterns as $pattern => $osName) {
        if (preg_match($pattern, $hostname)) {
            return $osName;
        }
    }
    
    // 4. Analizar por puertos abiertos
    if (!empty($openPorts)) {
        $portOSMap = [
            3389 => 'Windows',          // RDP
            5985 => 'Windows',          // WinRM HTTP
            5986 => 'Windows',          // WinRM HTTPS
            445 => 'Windows',           // SMB
            139 => 'Windows',           // NetBIOS
            135 => 'Windows',           // RPC
            22 => 'Linux/Unix (Generic)', // SSH
            23 => 'Network Device',     // Telnet
            161 => 'Network Device',    // SNMP
            162 => 'Network Device',    // SNMP Trap
            9100 => 'Printer',          // Raw Printing
            515 => 'Printer',           // LPR
            631 => 'Printer',           // IPP
            548 => 'macOS',             // AFP
            62078 => 'iOS',             // iPhone sync
            5353 => 'Apple Device',     // Bonjour/mDNS
            8006 => 'Proxmox VE',       // Proxmox Web
            8000 => 'Proxmox VE',       // Proxmox Alt
            943 => 'VMware',            // VMware Client
            902 => 'VMware',            // VMware Auth
            443 => 'Web Device',        // HTTPS (genérico)
            80 => 'Web Device',         // HTTP (genérico)
        ];
        
        // Contar ocurrencias de cada SO por puerto
        $portCounts = [];
        foreach ($openPorts as $port) {
            $portNum = is_array($port) ? $port['port'] : intval($port);
            if (isset($portOSMap[$portNum])) {
                $detectedOS = $portOSMap[$portNum];
                $portCounts[$detectedOS] = ($portCounts[$detectedOS] ?? 0) + 1;
            }
        }
        
        // Si hay puertos detectados, usar el más común
        if (!empty($portCounts)) {
            arsort($portCounts);
            $detectedOS = key($portCounts);
            
            // Si hay múltiples puertos del mismo SO, confiar más
            if ($portCounts[$detectedOS] > 1) {
                return $detectedOS;
            }
            
            // Si solo un puerto, verificar si es fuerte indicador
            $strongPorts = [3389, 22, 548, 62078, 8006, 943]; // Puertos muy específicos
            foreach ($openPorts as $port) {
                $portNum = is_array($port) ? $port['port'] : intval($port);
                if (in_array($portNum, $strongPorts) && isset($portOSMap[$portNum])) {
                    return $portOSMap[$portNum];
                }
            }
            
            return $detectedOS;
        }
    }
    
    // 5. Por TTL si está disponible
    if ($ttl !== null) {
        if ($ttl <= 64) {
            return 'Linux/Unix (Generic)';
        } elseif ($ttl <= 128) {
            return 'Windows (Generic)';
        } else {
            return 'Network Device';
        }
    }
    
    // 6. Fallback a genérico
    return 'Desconocido';
}

    
    private function persistHost($host) {
    $ip = $host['ip'];
    $mac = $host['mac'];
    $hostname = $host['hostname'];
    
    // Obtener datos del escáner
    $osFromScanner = $host['os'] ?? 'Unknown';
    $ttl = $host['ttl'] ?? null;
    $openPorts = $host['open_ports'] ?? [];
    $osHints = $host['os_hints'] ?? '';
    
    // VALIDAR MAC ANTES DE PROCESAR
    if ($mac) {
        // Normalizar formato MAC
        $mac = strtoupper($mac);
        $mac = str_replace(['-', '.'], ':', $mac);
        
        // Validar longitud (debe ser 17 caracteres con formato XX:XX:XX:XX:XX:XX)
        if (strlen($mac) != 17) {
            // Intentar formatear
            $mac = preg_replace('/[^A-Fa-f0-9]/', '', $mac);
            if (strlen($mac) == 12) {
                $mac = implode(':', str_split($mac, 2));
            } else {
                // MAC inválida, usar NULL
                $mac = null;
            }
        }
    } else {
        $mac = null;
    }
    
    // DETECTAR Y MAPEAR SISTEMA OPERATIVO
    $osName = $this->detectAndMapOS($osFromScanner, $hostname, $openPorts, $ttl);
    
    // Log para debugging
    writeLog("Host $ip -> OS Scanner: '$osFromScanner' -> Mapeado: '$osName' (TTL: " . ($ttl ?? 'N/A') . ", Hints: $osHints)", 'INFO');
    
    // Fabricante (OUI)
    $fabricanteId = 1; // Default desconocido
    
    if ($mac) {
        $oui = substr(str_replace(':', '', $mac), 0, 6);
        $fab = $this->fetchOne("SELECT id_fabricante FROM fabricantes WHERE oui_mac = ?", [$oui]);
        if ($fab) {
            $fabricanteId = $fab['id_fabricante'];
        }
    }
    
    // Sistema Operativo - obtener o crear ID
    $soId = $this->getOrCreateSO($osName);
    
    // Upsert Equipo CON MANEJO DE ERRORES MEJORADO
    try {
        $equipoId = $this->upsertEquipo($hostname, $ip, $mac, $soId, $fabricanteId);
        
        // Si hay puertos abiertos, procesarlos
        if (!empty($openPorts)) {
            foreach ($openPorts as $portInfo) {
                $portNum = is_array($portInfo) ? $portInfo['port'] : intval($portInfo);
                $protocolName = is_array($portInfo) ? ($portInfo['protocol'] ?? 'Unknown') : 'Unknown';
                
                // Obtener o crear protocolo
                $protoId = $this->getOrCreateProtocolo($portNum, $protocolName);
                
                // Vincular protocolo al equipo
                if ($protoId) {
                    $this->linkProtocolo($equipoId, $protoId, $portNum);
                }
            }
        }
        
        return $equipoId;
        
    } catch (PDOException $e) {
        // Si hay error de constraint, intentar con MAC nula
        if (strpos($e->getMessage(), 'chk_equipos_mac_length') !== false && $mac) {
            writeLog("Error de constraint MAC para $ip, intentando con MAC nula", 'WARNING');
            $equipoId = $this->upsertEquipo($hostname, $ip, null, $soId, $fabricanteId);
            return $equipoId;
        } else {
            throw $e;
        }
    }
}


    // --- Helpers SQL ---

    private function fetchOne($sql, $params) {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetch();
    }

    private function registrarConflicto($ip, $mac, $host, $desc) {
        $sql = "INSERT INTO conflictos (ip, mac, hostname_conflictivo, descripcion, estado, fecha_detectado) 
                VALUES (?, ?, ?, ?, 'detectado', NOW())";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([$ip, $mac, $host, $desc]);
        $this->stats['conflicts']++;
    }

    private function createFabricante($nombre, $oui) {
        try {
            $stmt = $this->pdo->prepare("INSERT INTO fabricantes (nombre, oui_mac) VALUES (?, ?)");
            $stmt->execute([$nombre, $oui]);
            return $this->pdo->lastInsertId();
        } catch (PDOException $e) {
            // Si falla, recuperar el ID default 1
            return 1;
        }
    }

    private function getOrCreateSO($nombre) {
    // Limpiar y normalizar nombre
    $nombre = trim($nombre);
    
    // Buscar primero coincidencia exacta
    $so = $this->fetchOne("SELECT id_so FROM sistemas_operativos WHERE nombre = ?", [$nombre]);
    
    if ($so) {
        writeLog("SO encontrado: '$nombre' -> ID: {$so['id_so']}", 'DEBUG');
        return $so['id_so'];
    }
    
    // Si no existe, intentar búsqueda aproximada (LIKE)
    $so = $this->fetchOne("SELECT id_so FROM sistemas_operativos WHERE nombre LIKE ? LIMIT 1", ["%$nombre%"]);
    
    if ($so) {
        writeLog("SO aproximado encontrado para '$nombre' -> ID: {$so['id_so']}", 'DEBUG');
        return $so['id_so'];
    }
    
    // Si no existe en absoluto, crear nuevo
    writeLog("Creando nuevo SO: '$nombre'", 'INFO');
    
    try {
        $stmt = $this->pdo->prepare("INSERT INTO sistemas_operativos (nombre) VALUES (?)");
        $stmt->execute([$nombre]);
        $newId = $this->pdo->lastInsertId();
        
        writeLog("Nuevo SO creado: '$nombre' -> ID: $newId", 'INFO');
        return $newId;
        
    } catch (PDOException $e) {
        // Si falla la inserción, usar el ID de "Desconocido"
        writeLog("Error creando SO '$nombre': " . $e->getMessage() . " - Usando 'Desconocido'", 'WARNING');
        
        $so = $this->fetchOne("SELECT id_so FROM sistemas_operativos WHERE nombre = 'Desconocido' OR nombre = 'Unknown' LIMIT 1");
        return $so ? $so['id_so'] : 1; // Fallback al ID 1
    }
}


    private function upsertEquipo($hostname, $ip, $mac, $soId, $fabId) {
        // Intentar actualizar por IP primero (Traer todos los datos para comparar)
        $existing = $this->fetchOne("SELECT * FROM equipos WHERE ip = ?", [$ip]);
        
        if ($existing) {
            $changes = false;
            $equipoId = $existing['id_equipo'];

            // 1. Detectar cambio de Hostname
            if (($existing['hostname'] != $hostname) && !empty($hostname) && $hostname != 'Desconocido') {
                $oldHost = $existing['hostname'] ?: 'N/A';
                $this->createAuditLog($equipoId, "Hostname actualizado: De '$oldHost' a '$hostname'");
            }

            // 2. Detectar cambio de OS
            if ($existing['id_so'] != $soId) {
                 // Opcional: Podríamos buscar el nombre del SO viejo/nuevo para ser más explícitos
                $this->createAuditLog($equipoId, "Sistema Operativo actualizado");
            }

            // 3. Detectar cambio de Fabricante (si era desconocido y ya no lo es)
            if ($existing['fabricante_id'] == 1 && $fabId != 1) {
                $this->createAuditLog($equipoId, "Fabricante identificado");
            }

            $sql = "UPDATE equipos SET hostname = ?, mac = ?, id_so = ?, fabricante_id = ?, ultima_deteccion = NOW() WHERE ip = ?";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute([$hostname, $mac, $soId, $fabId, $ip]);
            return $equipoId;
        } else {
            // Insertar o manejar duplicado de MAC
            try {
                $sql = "INSERT INTO equipos (hostname, ip, mac, id_so, fabricante_id, ultima_deteccion) 
                        VALUES (?, ?, ?, ?, ?, NOW())";
                $stmt = $this->pdo->prepare($sql);
                $stmt->execute([$hostname, $ip, $mac, $soId, $fabId]);
                $newId = $this->pdo->lastInsertId();

                // Log de Nuevo Dispositivo
                $this->createAuditLog($newId, "Nuevo dispositivo detectado: $hostname ($ip)");

                return $newId;
            } catch (PDOException $e) {
                // Error 23000 es violación de constraint (probablemente MAC duplicada)
                if ($e->getCode() == 23000 && strpos($e->getMessage(), 'mac') !== false) {
                    $sql = "UPDATE equipos SET hostname = ?, ip = ?, id_so = ?, fabricante_id = ?, ultima_deteccion = NOW() WHERE mac = ?";
                    $stmt = $this->pdo->prepare($sql);
                    $stmt->execute([$hostname, $ip, $soId, $fabId, $mac]);
                    
                    $rec = $this->fetchOne("SELECT id_equipo FROM equipos WHERE mac = ?", [$mac]);
                    return $rec['id_equipo'];
                }
                throw $e;
                private function createAuditLog($equipoId, $mensaje) {
        try {
            $sql = "INSERT INTO logs (id_equipo, mensaje, nivel, fecha_hora) VALUES (?, ?, 'info', NOW())";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute([$equipoId, $mensaje]);
        } catch (Exception $e) {
            // Silently fail logging to not disrupt main flow
            writeLog("Error writing audit log: " . $e->getMessage(), 'ERROR');
        }
    }
}
        }
    }

    private function getOrCreateProtocolo($port, $nombre, $categoria = 'otro') {
        $proto = $this->fetchOne("SELECT id_protocolo FROM protocolos WHERE numero = ? LIMIT 1", [$port]);
        if ($proto) return $proto['id_protocolo'];

        $stmt = $this->pdo->prepare("INSERT INTO protocolos (numero, nombre, categoria, descripcion) VALUES (?, ?, ?, 'Auto-detected')");
        try {
            $stmt->execute([$port, $nombre, $categoria]);
            return $this->pdo->lastInsertId();
        } catch (PDOException $e) {
            return null; // Fallback
        }
    }

    private function linkProtocolo($equipoId, $protoId, $port) {
        if (!$protoId) return;
        $sql = "INSERT INTO protocolos_usados (id_equipo, id_protocolo, puerto_detectado, fecha_hora, estado) 
                VALUES (?, ?, ?, NOW(), 'activo') 
                ON DUPLICATE KEY UPDATE fecha_hora = NOW()";
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute([$equipoId, $protoId, $port]);
    }
}

// -----------------------------------------------------------------------------
// 6. FLUJO PRINCIPAL
// -----------------------------------------------------------------------------

try {
    // Verificar método
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        sendResponse(true, 'API Online');
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendResponse(false, 'Método no permitido. Use POST.', [], 405);
    }

    // Leer Body
    $inputJSON = file_get_contents('php://input');
    $input = json_decode($inputJSON, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        sendResponse(false, 'JSON Malformado', [], 400);
    }

    writeLog("Request recibido: " . substr($inputJSON, 0, 100) . "...");

    // Validar y Enrutar
    if (isset($input['type']) && $input['type'] === 'metrics') {
        // --- PROCESAMIENTO DE MÉTRICAS (MONITOREO) ---
        $metrics = $input['data'] ?? [];
        if (empty($metrics)) {
             sendResponse(false, 'Datos de métricas vacíos', [], 400);
        }

        // Aquí podríamos guardar en una tabla 'metricas_equipos'
        // Por ahora, solo logueamos para verificar funcionamiento
        writeLog("Métricas recibidas de {$metrics['Hostname']} ({$metrics['IP']}): CPU={$metrics['CpuUsage']}%, RAM={$metrics['RamAvailableMb']}MB", 'METRICS');

        // Optional: Update device 'ultima_deteccion' based on IP
        // $pdo = getDbConnection();
        // $stmt = $pdo->prepare("UPDATE equipos SET ultima_deteccion = NOW() WHERE ip = ?");
        // $stmt->execute([$metrics['IP']]);

        sendResponse(true, 'Métricas recibidas correctamente');
    }
    else {
        // --- PROCESAMIENTO DE ESCANEO (DEFAULT) ---
        $errors = [];
        if (!validatePayload($input, $errors)) {
            writeLog("Error de validación: " . implode(", ", $errors), 'WARNING');
            sendResponse(false, 'Datos inválidos', ['errors' => $errors], 400);
        }

        // Conectar BD (Ya conectado via db_config.php en $pdo)
        // $pdo = getDbConnection(); // Comentado refactor

        // Normalizar
        $data = normalizePayload($input);

        // Procesar
        $processor = new Processor($pdo);
        $stats = $processor->process($data);

        writeLog("Procesamiento completado. Processed: {$stats['processed']}, Conflicts: {$stats['conflicts']}, Errors: {$stats['errors']}");

        // Respuesta Exitosa
        sendResponse(true, 'Scan procesado correctamente', $stats);
    }


} catch (Exception $e) {
    writeLog("Excepción General: " . $e->getMessage(), 'CRITICAL');
    sendResponse(false, 'Error interno del servidor', ['error' => $e->getMessage()], 500);
}

?>
