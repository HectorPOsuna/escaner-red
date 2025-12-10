<?php
// check_db.php - Verificar estructura de base de datos
header('Content-Type: application/json');

try {
    // Cargar configuración
    $configPath = __DIR__ . '/../db_config.php';
    require_once $configPath;
    
    if (!isset($pdo)) {
        throw new Exception("No database connection");
    }
    
    $result = [
        'connection' => 'OK',
        'tables' => []
    ];
    
    // Obtener todas las tablas
    $tables = $pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);
    
    foreach ($tables as $table) {
        $columns = $pdo->query("DESCRIBE `$table`")->fetchAll(PDO::FETCH_ASSOC);
        $rowCount = $pdo->query("SELECT COUNT(*) FROM `$table`")->fetchColumn();
        
        $result['tables'][$table] = [
            'columns' => array_column($columns, 'Field'),
            'row_count' => $rowCount
        ];
    }
    
    // Verificar tablas requeridas
    $requiredTables = ['equipos', 'sistemas_operativos', 'fabricantes', 'users'];
    $missingTables = [];
    
    foreach ($requiredTables as $table) {
        if (!in_array($table, $tables)) {
            $missingTables[] = $table;
        }
    }
    
    $result['missing_tables'] = $missingTables;
    
    echo json_encode($result, JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    echo json_encode([
        'error' => $e->getMessage(),
        'trace' => $e->getTraceAsString()
    ], JSON_PRETTY_PRINT);
}