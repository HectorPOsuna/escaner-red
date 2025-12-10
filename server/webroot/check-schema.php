<?php
/**
 * check-schema.php - Verificar esquema de tabla equipos
 * ELIMINAR DESPUÉS DE USAR
 */

header('Content-Type: application/json');

require_once __DIR__ . '/db_config.php';

try {
    // Obtener estructura de la tabla equipos
    $stmt = $pdo->query("DESCRIBE equipos");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $columnNames = array_column($columns, 'Field');
    
    echo json_encode([
        'success' => true,
        'table' => 'equipos',
        'columns' => $columns,
        'column_names' => $columnNames,
        'has_os_hints' => in_array('os_hints', $columnNames),
        'total_columns' => count($columns)
    ], JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}
