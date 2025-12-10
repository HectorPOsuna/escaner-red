<?php
// test.php - Endpoint de prueba simple
header('Content-Type: application/json');

try {
    // Cargar configuración
    $configPath = __DIR__ . '/../../db_config.php';
    
    if (!file_exists($configPath)) {
        throw new Exception("db_config.php not found at: " . $configPath);
    }
    
    require_once $configPath;
    
    // Verificar conexión
    if (!isset($pdo)) {
        throw new Exception("\$pdo is not defined");
    }
    
    // Probar conexión simple
    $test = $pdo->query("SELECT 1 as test")->fetch();
    
    // Contar equipos
    $count = $pdo->query("SELECT COUNT(*) FROM equipos")->fetchColumn();
    
    echo json_encode([
        'success' => true,
        'message' => 'Database connection OK',
        'test' => $test,
        'equipos_count' => $count,
        'pdo_info' => [
            'driver' => $pdo->getAttribute(PDO::ATTR_DRIVER_NAME),
            'client_version' => $pdo->getAttribute(PDO::ATTR_CLIENT_VERSION),
            'server_version' => $pdo->getAttribute(PDO::ATTR_SERVER_VERSION)
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine(),
        'trace' => $e->getTraceAsString()
    ]);
}