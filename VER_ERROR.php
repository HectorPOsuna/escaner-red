<?php
// ESTE ARCHIVO VA EN: /lisi3309/server/api/VER_ERROR.php
// Debes COPIAR Y PEGAR este código COMPLETO

error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('html_errors', 1);

echo "<!DOCTYPE html><html><head><title>VER ERROR 500</title><style>
body { font-family: Arial; padding: 20px; background: #f0f0f0; }
.error { color: red; background: white; padding: 15px; border: 2px solid red; }
.ok { color: green; }
pre { background: #222; color: #0f0; padding: 10px; }
</style></head><body>";

echo "<h1>🔍 VER ERROR 500 de dashboard.php</h1>";

// PRIMERO: Probar si podemos cargar db_config.php
echo "<h2>1. Probando db_config.php</h2>";

$config_path = dirname(__FILE__) . '/../db_config.php';
echo "Ruta: <code>" . realpath($config_path) . "</code><br>";

if (file_exists($config_path)) {
    echo "<span class='ok'>✅ Existe</span><br>";
    
    // Leer primeras líneas para ver contenido
    $lines = file($config_path, FILE_IGNORE_NEW_LINES);
    echo "Primeras 10 líneas:<br><pre>";
    for ($i = 0; $i < min(10, count($lines)); $i++) {
        echo htmlspecialchars($lines[$i]) . "\n";
    }
    echo "</pre>";
    
    // Intentar cargarlo
    try {
        require_once $config_path;
        echo "<span class='ok'>✅ Cargado sin errores</span><br>";
        
        if (isset($pdo)) {
            echo "<span class='ok'>✅ \$pdo está definido</span><br>";
        } else {
            echo "<span class='error'>❌ \$pdo NO está definido</span><br>";
        }
    } catch (Exception $e) {
        echo "<span class='error'>❌ ERROR al cargar: " . $e->getMessage() . "</span><br>";
    }
    
} else {
    echo "<span class='error'>❌ NO EXISTE</span><br>";
}

// SEGUNDO: Probar dashboard.php DIRECTAMENTE
echo "<h2>2. Probando dashboard.php directamente</h2>";
echo "<p>Haz clic en este enlace para ver el error REAL:</p>";
echo "<p><a href='dashboard.php?action=list&limit=5' target='_blank' style='font-size: 20px; background: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;'>👉 VER ERROR EN dashboard.php</a></p>";

// TERCERO: Si dashboard.php sigue dando error, creamos una versión ULTRA simple
echo "<h2>3. Crear dashboard.php NUEVO (si sigue fallando)</h2>";
echo "<p>Copia este código y PÉGALO en dashboard.php:</p>";
echo "<textarea style='width: 100%; height: 300px; font-family: monospace;'>" . htmlspecialchars('<?php
// VERSIÓN ULTRA SIMPLE de dashboard.php
error_reporting(E_ALL);
ini_set(\'display_errors\', 1);

require_once __DIR__ . \'/../db_config.php\';

// Saltar autenticación TEMPORALMENTE para debug
// require_once __DIR__ . \'/auth/check.php\';
// $auth = checkAuthentication();
// if (!$auth[\'authenticated\']) {
//     http_response_code(401);
//     echo json_encode([\'success\' => false, \'error\' => \'Unauthorized\']);
//     exit;
// }

header(\'Content-Type: application/json\');

try {
    // Consulta SUPER simple
    $sql = "SELECT e.id_equipo, e.hostname, e.ip, e.mac, e.id_so 
            FROM equipos e 
            LIMIT 5";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $devices = $stmt->fetchAll();
    
    echo json_encode([
        \'success\' => true,
        \'message\' => \'Test funcionando\',
        \'data\' => $devices,
        \'total\' => count($devices)
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        \'success\' => false, 
        \'error\' => $e->getMessage(),
        \'trace\' => $e->getTraceAsString()
    ]);
}
?>') . "</textarea>";

echo "</body></html>";