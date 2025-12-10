<?php
// check.php - VERSIÓN MEJORADA (retorna, no imprime)

function checkAuthentication() {
    if (session_status() === PHP_SESSION_NONE) {
        ini_set('session.cookie_httponly', 1);
        ini_set('session.cookie_secure', 1);
        session_start();
    }
    
    if (isset($_SESSION['user_id'])) {
        return [
            'authenticated' => true,
            'user' => [
                'username' => $_SESSION['username'],
                'role' => $_SESSION['role']
            ],
            'csrf_token' => $_SESSION['csrf_token']
        ];
    } else {
        return ['authenticated' => false];
    }
}

// Si se accede directamente, sí imprimir (para compatibilidad)
if (basename(__FILE__) == basename($_SERVER['PHP_SELF'])) {
    header('Content-Type: application/json');
    echo json_encode(checkAuthentication());
    exit;
}