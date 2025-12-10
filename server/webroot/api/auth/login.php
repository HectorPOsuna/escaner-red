<?php
/**
 * API/Auth/Login Endpoint
 * 
 * Handles user authentication via POST.
 * Returns JSON with status and CSRF token.
 */

require_once __DIR__ . '/../../db_config.php'; // Allow this to fail initially if file doesn't exist, we will create it.

// Security Headers
header('Content-Type: application/json');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');

// Start Session Securely
if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.cookie_httponly', 1);
    ini_set('session.cookie_secure', 1); // Require HTTPS
    ini_set('session.use_strict_mode', 1);
    session_start();
}

// 1. Validate Input
$input = json_decode(file_get_contents('php://input'), true);
if (!isset($input['username']) || !isset($input['password'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing credentials']);
    exit;
}

$username = trim($input['username']);
$password = $input['password'];

try {
    // 2. Database Connection
    // Assuming $pdo is available from db_config.php or we create it here for now
    if (!isset($pdo)) {
        // Fallback or todo: Move this to a shared config file
        $host = getenv('DB_HOST') ?: 'localhost';
        $db   = getenv('DB_NAME') ?: 'network_scanner';
        $user = getenv('DB_USER') ?: 'root';
        $pass = getenv('DB_PASS') ?: '';
        $charset = 'utf8mb4';
        
        $dsn = "mysql:host=$host;dbname=$db;charset=$charset";
        $options = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ];
        $pdo = new PDO($dsn, $user, $pass, $options);
    }

    // 3. Verify User
    $stmt = $pdo->prepare("SELECT id, username, password_hash, role FROM users WHERE username = ? LIMIT 1");
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if ($user && password_verify($password, $user['password_hash'])) {
        // 4. Create Session
        session_regenerate_id(true); // Anti-Session Fixation
        $_SESSION['user_id'] = $user['id'];
        $_SESSION['username'] = $user['username'];
        $_SESSION['role'] = $user['role'];
        $_SESSION['created'] = time();
        
        // Generate CSRF Token for subsequent requests
        if (empty($_SESSION['csrf_token'])) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        }

        // Update Last Login
        $update = $pdo->prepare("UPDATE users SET last_login = NOW() WHERE id = ?");
        $update->execute([$user['id']]);

        echo json_encode([
            'success' => true,
            'user' => [
                'username' => $user['username'],
                'role' => $user['role']
            ],
            'csrf_token' => $_SESSION['csrf_token']
        ]);
    } else {
        // Timing mitigation (sleep random microseconds?)
        usleep(rand(100000, 300000)); 
        http_response_code(401);
        echo json_encode(['error' => 'Invalid credentials']);
    }

} catch (\PDOException $e) {
    error_log("Login Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Internal Server Error']);
}
