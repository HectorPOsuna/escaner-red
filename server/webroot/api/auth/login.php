<?php
/**
 * API/Auth/Login Endpoint
 * 
 * Handles user authentication via POST.
 * Returns JSON with status and CSRF token.
 */

// 1. INICIAR OUTPUT BUFFER (evitar errores de headers)
ob_start();

// 2. Cargar configuración DE FORMA SEGURA
$configPath = __DIR__ . '/../../db_config.php';
if (!file_exists($configPath)) {
    ob_end_clean();
    http_response_code(500);
    echo json_encode(['error' => 'Configuration file missing']);
    exit;
}

require_once $configPath;

// 3. Security Headers
header('Content-Type: application/json');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');

// 4. Start Session Securely
if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.cookie_httponly', 1);
    ini_set('session.cookie_secure', 1); // Require HTTPS
    ini_set('session.use_strict_mode', 1);
    session_start();
}

// 5. Validate Input
$input = json_decode(file_get_contents('php://input'), true);
if (!isset($input['username']) || !isset($input['password'])) {
    ob_end_clean();
    http_response_code(400);
    echo json_encode(['error' => 'Missing credentials']);
    exit;
}

$username = trim($input['username']);
$password = $input['password'];

try {
    // 6. VERIFICAR QUE $pdo EXISTE (de db_config.php)
    if (!isset($pdo)) {
        throw new Exception('Database connection not initialized');
    }

    // 7. Verify User
    $stmt = $pdo->prepare("SELECT id, username, password_hash, role FROM users WHERE username = ? LIMIT 1");
    $stmt->execute([$username]);
    $user = $stmt->fetch();

    if ($user && password_verify($password, $user['password_hash'])) {
        // 8. Create Session
        session_regenerate_id(true);
        $_SESSION['user_id'] = (int)$user['id'];
        $_SESSION['username'] = $user['username'];
        $_SESSION['role'] = $user['role'];
        $_SESSION['created'] = time();
        
        // Generate CSRF Token
        if (empty($_SESSION['csrf_token'])) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        }

        // Update Last Login
        $update = $pdo->prepare("UPDATE users SET last_login = NOW() WHERE id = ?");
        $update->execute([$user['id']]);

        // 9. RESPONSE EXITOSO
        ob_end_clean();
        echo json_encode([
            'success' => true,
            'user' => [
                'username' => $user['username'],
                'role' => $user['role']
            ],
            'csrf_token' => $_SESSION['csrf_token']
        ]);
        exit;
        
    } else {
        // Timing mitigation
        usleep(rand(100000, 300000)); 
        
        ob_end_clean();
        http_response_code(401);
        echo json_encode(['error' => 'Invalid credentials']);
        exit;
    }

} catch (\PDOException $e) {
    error_log("Login PDO Error: " . $e->getMessage());
    
    ob_end_clean();
    http_response_code(500);
    echo json_encode(['error' => 'Database error']);
    exit;
    
} catch (\Exception $e) {
    error_log("Login General Error: " . $e->getMessage());
    
    ob_end_clean();
    http_response_code(500);
    echo json_encode(['error' => 'Internal server error']);
    exit;
}

// 10. Limpiar buffer por si acaso
ob_end_flush();
?>