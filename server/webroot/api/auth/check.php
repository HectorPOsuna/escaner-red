<?php
/**
 * check.php - Verificación de Autenticación
 * Ubicación: /lisi3309/api/auth/check.php
 */

// Headers
header('Content-Type: application/json');
header('Access-Control-Allow-Credentials: true');
header('Cache-Control: no-cache, must-revalidate');

// Iniciar sesión si no está iniciada
if (session_status() === PHP_SESSION_NONE) {
    // Configurar sesión segura
    ini_set('session.cookie_httponly', 1);
    ini_set('session.cookie_samesite', 'Lax');
    ini_set('session.use_strict_mode', 1);
    
    // Solo usar secure en HTTPS
    if (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') {
        ini_set('session.cookie_secure', 1);
    }
    
    session_start();
}

// Preparar respuesta
$response = [
    'authenticated' => false,
    'user' => null,
    'csrf_token' => null
];

// Verificar si hay sesión activa
if (isset($_SESSION['user_id']) && isset($_SESSION['username'])) {
    $response['authenticated'] = true;
    $response['user'] = [
        'id' => $_SESSION['user_id'],
        'username' => $_SESSION['username'],
        'role' => $_SESSION['role'] ?? 'user'
    ];
    $response['csrf_token'] = $_SESSION['csrf_token'] ?? null;
}

// Enviar respuesta
echo json_encode($response);
exit;