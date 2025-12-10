<?php
/**
 * test-auth.php - Archivo de prueba para verificar autenticación
 * ELIMINAR DESPUÉS DE PROBAR
 */

header('Content-Type: application/json');

// Información de debug
$debug = [
    'timestamp' => date('Y-m-d H:i:s'),
    'server' => [
        'php_version' => phpversion(),
        'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'unknown',
        'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? 'unknown',
        'script_filename' => __FILE__,
        'request_uri' => $_SERVER['REQUEST_URI'] ?? 'unknown'
    ],
    'session' => [
        'status' => session_status(),
        'status_text' => [
            PHP_SESSION_DISABLED => 'DISABLED',
            PHP_SESSION_NONE => 'NONE',
            PHP_SESSION_ACTIVE => 'ACTIVE'
        ][session_status()],
        'id' => session_id() ?: 'no session',
        'save_path' => session_save_path(),
        'cookie_params' => session_get_cookie_params()
    ]
];

// Intentar iniciar sesión
if (session_status() === PHP_SESSION_NONE) {
    session_start();
    $debug['session']['started'] = true;
    $debug['session']['id_after_start'] = session_id();
} else {
    $debug['session']['started'] = false;
}

// Datos de sesión
$debug['session']['data'] = $_SESSION ?? [];

// Verificar archivo check.php
$checkPath = __DIR__ . '/api/auth/check.php';
$debug['files'] = [
    'check_php_exists' => file_exists($checkPath),
    'check_php_path' => $checkPath,
    'check_php_readable' => is_readable($checkPath)
];

// Intentar llamar a check.php
if (file_exists($checkPath)) {
    ob_start();
    try {
        include $checkPath;
        $checkOutput = ob_get_clean();
        $debug['check_php_output'] = $checkOutput;
        $debug['check_php_json'] = json_decode($checkOutput, true);
    } catch (Exception $e) {
        ob_end_clean();
        $debug['check_php_error'] = $e->getMessage();
    }
}

echo json_encode($debug, JSON_PRETTY_PRINT);
