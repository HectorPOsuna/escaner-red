<?php
header('Content-Type: application/json');

if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.cookie_httponly', 1);
    ini_set('session.cookie_secure', 1);
    session_start();
}

if (isset($_SESSION['user_id'])) {
    echo json_encode([
        'authenticated' => true,
        'user' => [
            'username' => $_SESSION['username'],
            'role' => $_SESSION['role']
        ],
        'csrf_token' => $_SESSION['csrf_token']
    ]);
} else {
    echo json_encode(['authenticated' => false]);
}
