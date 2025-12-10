<?php
/**
 * test-endpoints.php - Verificar endpoints de API
 * ELIMINAR DESPUÉS DE PROBAR
 */

header('Content-Type: application/json');

$results = [];

// Test 1: Verificar db_config.php
$dbConfigPath = __DIR__ . '/db_config.php';
$results['db_config'] = [
    'path' => $dbConfigPath,
    'exists' => file_exists($dbConfigPath),
    'readable' => is_readable($dbConfigPath)
];

// Test 2: Intentar cargar db_config
if (file_exists($dbConfigPath)) {
    try {
        require_once $dbConfigPath;
        $results['db_config']['loaded'] = true;
        $results['db_config']['pdo_exists'] = isset($pdo);
        
        if (isset($pdo)) {
            $results['db_config']['pdo_connected'] = true;
            
            // Test query
            try {
                $stmt = $pdo->query("SELECT COUNT(*) as total FROM equipos");
                $count = $stmt->fetchColumn();
                $results['database']['equipos_count'] = $count;
            } catch (Exception $e) {
                $results['database']['error'] = $e->getMessage();
            }
        }
    } catch (Exception $e) {
        $results['db_config']['error'] = $e->getMessage();
    }
}

// Test 3: Verificar archivos de API
$apiFiles = [
    'dashboard' => __DIR__ . '/api/dashboard.php',
    'metrics' => __DIR__ . '/api/metrics.php',
    'check' => __DIR__ . '/api/auth/check.php',
    'login' => __DIR__ . '/api/auth/login.php'
];

foreach ($apiFiles as $name => $path) {
    $results['api_files'][$name] = [
        'path' => $path,
        'exists' => file_exists($path),
        'readable' => is_readable($path)
    ];
}

// Test 4: Verificar sesión
session_start();
$results['session'] = [
    'status' => session_status(),
    'id' => session_id(),
    'authenticated' => isset($_SESSION['user_id']),
    'user_id' => $_SESSION['user_id'] ?? null,
    'username' => $_SESSION['username'] ?? null
];

// Test 5: Simular llamada a dashboard.php
if (isset($pdo)) {
    try {
        $stmt = $pdo->query("SELECT COUNT(*) as total FROM equipos");
        $total = (int)$stmt->fetchColumn();
        
        $stmt = $pdo->prepare("SELECT COUNT(*) as activos FROM equipos WHERE ultima_deteccion >= NOW() - INTERVAL 5 MINUTE");
        $stmt->execute();
        $activos = (int)$stmt->fetchColumn();
        
        $results['dashboard_simulation'] = [
            'success' => true,
            'total_equipos' => $total,
            'activos_5min' => $activos
        ];
    } catch (Exception $e) {
        $results['dashboard_simulation'] = [
            'success' => false,
            'error' => $e->getMessage()
        ];
    }
}

echo json_encode($results, JSON_PRETTY_PRINT);
