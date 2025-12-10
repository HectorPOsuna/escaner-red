<?php
require_once __DIR__ . '/../../db_config.php';

if (session_status() === PHP_SESSION_NONE) session_start();
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

$secureDir = __DIR__ . '/../../../secure_downloads/';
$files = [];

if (is_dir($secureDir)) {
    $scanned = scandir($secureDir);
    foreach ($scanned as $file) {
        if ($file !== '.' && $file !== '..') {
            $files[] = [
                'name' => $file,
                'size' => filesize($secureDir . $file),
                'date' => date('Y-m-d H:i:s', filemtime($secureDir . $file))
            ];
        }
    }
}

echo json_encode($files);
