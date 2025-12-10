<?php
require_once __DIR__ . '/../../../db_config.php';

// Auth Check
if (session_status() === PHP_SESSION_NONE) session_start();
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
// For this environment, we might put it in d:\GITHUB\escaner-red\secure_downloads
$secureDir = __DIR__ . '/../../secure_downloads/';

// Fix Path Traversal
$filename = basename($_GET['file'] ?? '');

if (!$filename || !file_exists($secureDir . $filename)) {
    http_response_code(404);
    die('File not found');
}

// Log Download (Optional)
// $pdo->prepare("INSERT INTO downloads ...")->execute(...)

// Serve File
header('Content-Description: File Transfer');
header('Content-Type: application/octet-stream');
header('Content-Disposition: attachment; filename="' . $filename . '"');
header('Expires: 0');
header('Cache-Control: must-revalidate');
header('Pragma: public');
header('Content-Length: ' . filesize($secureDir . $filename));
readfile($secureDir . $filename);
exit;
