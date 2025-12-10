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

// -----------------------------------------------------------------------------
// 3. CONEXIÓN BASE DE DATOS
// -----------------------------------------------------------------------------

function getDbConnection() {
    global $rootDir;
    
    $envPath = $rootDir . '/.env';
    loadEnv($envPath);

    $host = $_ENV['DB_HOST'] ?? 'localhost';
    $port = $_ENV['DB_PORT'] ?? 3306;
    $db   = $_ENV['DB_NAME'] ?? 'red_monitor';
    $user = $_ENV['DB_USER'] ?? 'root';
    $pass = $_ENV['DB_PASSWORD'] ?? '';
    $charset = 'utf8mb4';

    $dsn = "mysql:host=$host;port=$port;dbname=$db;charset=$charset";
    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ];

    try {
        return new PDO($dsn, $user, $pass, $options);
    } catch (PDOException $e) {
        writeLog("Error de conexión DB: " . $e->getMessage(), 'CRITICAL');
        throw new Exception("Error conectando a la base de datos");
    }
}

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
        
        // Parsear puertos
        $ports = [];
        if (is_array($openPortsRaw)) {
            $ports = $openPortsRaw;
        } elseif (is_string($openPortsRaw) && !empty($openPortsRaw)) {
            $parts = explode(',', $openPortsRaw);
            foreach ($parts as $p) {
                $p = trim($p);
                if (is_numeric($p)) {
                    $ports[] = ['port' => intval($p), 'protocol' => 'Unknown'];
                }
            }
        }

        $hosts[] = [
            'ip' => $ip,
            'mac' => $mac,
            'hostname' => $hostname,
            'manufacturer' => 'Desconocido', // Será resuelto por OUI después
            'os' => 'Unknown',
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

    private function persistHost($host) {
        $ip = $host['ip'];
        $mac = $host['mac'];
        $hostname = $host['hostname'];
        $osName = $host['os'] ?? 'Unknown';
        
        // Fabricante (OUI)
        $fabricanteId = null;
        if ($mac) {
            $oui = substr(str_replace([':', '-'], '', $mac), 0, 6);
            $fab = $this->fetchOne("SELECT id_fabricante FROM fabricantes WHERE oui_mac = ?", [$oui]);
            if ($fab) {
                $fabricanteId = $fab['id_fabricante'];
            } else {
                // Crear fabricante por defecto
                $fabricanteId = $this->createFabricante('Desconocido', $oui);
            }
        } else {
            // ID 1 suele ser desconocido en seeds
            $fabricanteId = 1; 
        }

        // Sistema Operativo
        $soId = $this->getOrCreateSO($osName);

        // Upsert Equipo
        $equipoId = $this->upsertEquipo($hostname, $ip, $mac, $soId, $fabricanteId);

        // Protocolos
        foreach ($host['open_ports'] as $p) {
            $port = $p['port'];
            $protoName = $p['protocol'] ?? 'Unknown';
            $category = $p['category'] ?? 'otro';
            
            // Validar que la categoría sea válida según el ENUM, si no, fallback a 'otro'
            $validCategories = ['seguro', 'inseguro', 'precaucion', 'inusual', 'esencial', 'base_de_datos', 'correo'];
            if (!in_array($category, $validCategories)) {
                $category = 'otro';
            }
            
            $protoId = $this->getOrCreateProtocolo($port, $protoName, $category);
            $this->linkProtocolo($equipoId, $protoId, $port);
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
        $so = $this->fetchOne("SELECT id_so FROM sistemas_operativos WHERE nombre = ?", [$nombre]);
        if ($so) return $so['id_so'];

        $stmt = $this->pdo->prepare("INSERT INTO sistemas_operativos (nombre) VALUES (?)");
        $stmt->execute([$nombre]);
        return $this->pdo->lastInsertId();
    }

    private function upsertEquipo($hostname, $ip, $mac, $soId, $fabId) {
        // Intentar actualizar por IP primero
        $existing = $this->fetchOne("SELECT id_equipo FROM equipos WHERE ip = ?", [$ip]);
        
        if ($existing) {
            $sql = "UPDATE equipos SET hostname = ?, mac = ?, id_so = ?, fabricante_id = ?, ultima_deteccion = NOW() WHERE ip = ?";
            $stmt = $this->pdo->prepare($sql);
            $stmt->execute([$hostname, $mac, $soId, $fabId, $ip]);
            return $existing['id_equipo'];
        } else {
            // Insertar o manejar duplicado de MAC
            try {
                $sql = "INSERT INTO equipos (hostname, ip, mac, id_so, fabricante_id, ultima_deteccion) 
                        VALUES (?, ?, ?, ?, ?, NOW())";
                $stmt = $this->pdo->prepare($sql);
                $stmt->execute([$hostname, $ip, $mac, $soId, $fabId]);
                return $this->pdo->lastInsertId();
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

        // Conectar BD
        $pdo = getDbConnection();

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
