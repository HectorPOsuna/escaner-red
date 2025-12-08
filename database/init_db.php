<?php
/**
 * Database Initialization Script (PHP)
 * 
 * Replaces initDB.js
 */

require_once __DIR__ . '/../server/db.php';

echo "🚀 Iniciando inicialización de base de datos...\n";

try {
    $pdo = getDbConnection();
    
    // Leer archivo SQL
    $sqlFile = __DIR__ . '/migrations/init_database.sql';
    if (!file_exists($sqlFile)) {
        throw new Exception("No se encontró el archivo SQL: $sqlFile");
    }

    $sql = file_get_contents($sqlFile);

    // Ejecutar múltiples sentencias
    // PDO no soporta múltiples sentencias en una sola llamada prepare/execute de forma estándar en todos los drivers,
    // pero MySQL suele permitirlo si se configura.
    // Sin embargo, para mayor seguridad, podemos dividir por ; si es necesario, 
    // pero init_database.sql puede tener triggers o procedures.
    // Intentaremos ejecutarlo directo.
    
    $pdo->exec($sql);
    
    echo "✅ Esquema de base de datos aplicado correctamente.\n";

    // Ejecutar seeds
    echo "🌱 Ejecutando seeds...\n";
    
    // Seed OUI
    include __DIR__ . '/seed/seed_oui.php';
    
    // Seed Protocolos
    include __DIR__ . '/seed/seed_protocolos.php';

    echo "✅ Inicialización completa.\n";

} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
?>
