<?php
// db_config.php - en /lisi3309/includes/
define('ROOT_PATH', dirname(__DIR__));

// Función para cargar .env
function loadEnv($path) {
    if (!file_exists($path)) {
        throw new Exception("Archivo .env no encontrado: $path");
    }
    
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        if (strpos($line, '=') !== false) {
            list($name, $value) = explode('=', $line, 2);
            $name = trim($name);
            $value = trim($value);
            // Remover comillas
            $value = trim($value, "\"'");
            $_ENV[$name] = $value;
        }
    }
}

// Cargar .env
try {
    loadEnv(ROOT_PATH . '/.env');
} catch (Exception $e) {
    error_log("Error loading .env: " . $e->getMessage());
    die("Configuration error. Please check .env file.");
}

// Configuración de conexión
$config = [
    'host' => $_ENV['DB_HOST'] ?? 'dsantana.fimaz.uas.edu.mx',
    'port' => $_ENV['DB_PORT'] ?? 3306,
    'dbname' => $_ENV['DB_NAME'] ?? 'lisi3309',
    'username' => $_ENV['DB_USER'] ?? 'lisi3309',
    'password' => $_ENV['DB_PASSWORD'] ?? '123tamarindo',
    'charset' => 'utf8mb4'
];

try {
    $dsn = "mysql:host={$config['host']};port={$config['port']};dbname={$config['dbname']};charset={$config['charset']}";
    $pdo = new PDO($dsn, $config['username'], $config['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
        PDO::ATTR_PERSISTENT => false
    ]);
    
    // Configurar timezone si es necesario
    $pdo->exec("SET time_zone = 'America/Mazatlan'");
    
} catch (PDOException $e) {
    error_log("Database Connection Error: " . $e->getMessage());
    
    // Mensajes amigables según el error
    $errorCode = $e->getCode();
    switch ($errorCode) {
        case 2002:
            $message = "No se puede conectar al servidor MySQL. Verifica el host y puerto.";
            break;
        case 1045:
            $message = "Acceso denegado. Verifica usuario y contraseña.";
            break;
        case 1049:
            $message = "La base de datos '{$config['dbname']}' no existe.";
            break;
        default:
            $message = "Error de base de datos: " . $e->getMessage();
    }
    
    if ($_ENV['DEBUG'] ?? false) {
        die("<h3>Error de Base de Datos</h3><p>$message</p><p>Detalles: " . $e->getMessage() . "</p>");
    } else {
        die("<h3>Error del Sistema</h3><p>Por favor, contacta al administrador.</p>");
    }
}
?>