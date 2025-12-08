<?php
/**
 * API REST - Recepción de Datos de Escaneo
 * 
 * Endpoint: POST /api/receive.php
 * Content-Type: application/json
 * 
 * Formato esperado:
 * {
 *   "Devices": [
 *     {
 *       "IP": "192.168.1.100",
 *       "MAC": "AA:BB:CC:DD:EE:FF",
 *       "Hostname": "PC-EJEMPLO",
 *       "OpenPorts": "80,443,3306"
 *     }
 *   ]
 * }
 */

// Headers CORS y JSON
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Manejar preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Solo aceptar POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Método no permitido. Use POST.'
    ]);
    exit;
}

// Cargar dependencias
require_once __DIR__ . '/ApiValidator.php';
require_once __DIR__ . '/../ScanProcessor.php';

// Función de logging
function logRequest($message, $data = null) {
    $logFile = __DIR__ . '/../../logs/api_requests.log';
    $logDir = dirname($logFile);
    
    if (!is_dir($logDir)) {
        @mkdir($logDir, 0755, true);
    }
    
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] $message";
    
    if ($data !== null) {
        $logEntry .= " | Data: " . json_encode($data);
    }
    
    $logEntry .= PHP_EOL;
    
    @file_put_contents($logFile, $logEntry, FILE_APPEND);
}

try {
    // Leer el cuerpo de la petición
    $rawInput = file_get_contents('php://input');
    
    if (empty($rawInput)) {
        throw new Exception('Cuerpo de la petición vacío');
    }

    // Decodificar JSON
    $inputData = json_decode($rawInput, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('JSON inválido: ' . json_last_error_msg());
    }

    logRequest('Petición recibida', [
        'ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
        'devices_count' => count($inputData['Devices'] ?? [])
    ]);

    // Validar payload
    $validator = new ApiValidator();
    
    if (!$validator->validateScanPayload($inputData)) {
        $errors = $validator->getErrors();
        logRequest('Validación fallida', $errors);
        
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Datos inválidos',
            'errors' => $errors
        ]);
        exit;
    }

    // Normalizar al formato interno
    $normalizedData = $validator->normalizePayload($inputData);

    // Procesar datos usando ScanProcessor
    $processor = new ScanProcessor();
    $results = $processor->processScanData($normalizedData);

    logRequest('Procesamiento exitoso', $results);

    // Respuesta exitosa
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Datos recibidos correctamente',
        'summary' => [
            'processed' => $results['processed'],
            'conflicts' => $results['conflicts'],
            'errors' => $results['errors']
        ]
    ]);

} catch (Exception $e) {
    logRequest('Error fatal', ['error' => $e->getMessage()]);
    
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error del servidor: ' . $e->getMessage()
    ]);
}
?>
