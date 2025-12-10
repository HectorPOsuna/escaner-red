<?php
// test-db.php
session_start();
header('Content-Type: application/json');

try {
    require_once __DIR__ . '/db_config.php';
    
    echo json_encode([
        'success' => true,
        'database' => [
            'connected' => isset($pdo),
            'connection' => $pdo ? 'OK' : 'NO',
            'host' => $db_host ?? 'unknown',
            'name' => $db_name ?? 'unknown'
        ],
        'tables' => []
    ]);
    
    if (isset($pdo)) {
        $stmt = $pdo->query("SHOW TABLES");
        $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
        
        echo json_encode([
            'success' => true,
            'database' => [
                'connected' => true,
                'tables_count' => count($tables),
                'tables' => $tables
            ]
        ]);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ]);
}