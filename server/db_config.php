<?php
/**
 * db_config.php - Configuración de Base de Datos
 * Ubicación: /lisi3309/db_config.php (raíz del proyecto web)
 */

// Cargar variables de entorno desde .env si existe
function loadEnvFile($path) {
    if (!file_exists($path)) {
        return false;
    }
    
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if (empty($line) || $line[0] === '#') {
            continue;
        }
        
        if (strpos($line, '=') !== false) {
            list($name, $value) = explode('=', $line, 2);
            $name = trim($name);
            $value = trim($value);
            $value = trim($value, "\"'");
            
            if (!isset($_ENV[$name])) {
                $_ENV[$name] = $value;
                putenv("$name=$value");
            }
        }
    }
    return true;
}

// Intentar cargar .env
$envPath = __DIR__ . '/.env';
loadEnvFile($envPath);

// Configuración de conexión usando variables de entorno
$dbConfig = [
    'host' => getenv('DB_HOST') ?: ($_ENV['DB_HOST'] ?? 'dsantana.fimaz.uas.edu.mx'),
    'port' => getenv('DB_PORT') ?: ($_ENV['DB_PORT'] ?? 3306),
    'dbname' => getenv('DB_NAME') ?: ($_ENV['DB_NAME'] ?? 'lisi3309'),
    'username' => getenv('DB_USER') ?: ($_ENV['DB_USER'] ?? 'lisi3309'),
    'password' => getenv('DB_PASSWORD') ?: ($_ENV['DB_PASSWORD'] ?? ''),
    'charset' => 'utf8mb4'
];

try {
    $dsn = sprintf(
        "mysql:host=%s;port=%d;dbname=%s;charset=%s",
        $dbConfig['host'],
        $dbConfig['port'],
        $dbConfig['dbname'],
        $dbConfig['charset']
    );
    
    $pdo = new PDO($dsn, $dbConfig['username'], $dbConfig['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
        PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci"
    ]);
    
    // Configurar zona horaria
    $pdo->exec("SET time_zone = 'America/Mazatlan'");
    
} catch (PDOException $e) {
    error_log("Database Connection Error: " . $e->getMessage());
    
    // Respuesta JSON si es una petición API
    if (isset($_SERVER['REQUEST_URI']) && strpos($_SERVER['REQUEST_URI'], '/api/') !== false) {
        header('Content-Type: application/json');
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'Database connection failed',
            'message' => 'No se pudo conectar a la base de datos'
        ]);
        exit;
    }
    
    // Mensaje de error genérico
    die('<h3>Error de Conexión</h3><p>No se pudo conectar a la base de datos. Por favor, contacta al administrador.</p>');
}