<?php
require_once __DIR__ . '/../db_config.php';
require_once __DIR__ . '/auth/check.php'; // Verifies session via include or logic

// Ensure request comes from authenticated user
if (session_status() === PHP_SESSION_NONE) session_start();
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

header('Content-Type: application/json');

$action = $_GET['action'] ?? 'summary';

try {
    if ($action === 'summary') {
        // Summary Cards
        $total = $pdo->query("SELECT COUNT(*) FROM equipos")->fetchColumn();
        
        // Count by risk logic (assuming 'protocolos' table or logic exists, here we simplify)
        // If risk is not stored, we might mock or query differently. 
        // For now, let's assume we have a way to count or just return total.
        // We will fetch latest captures count too.
        
        echo json_encode([
            'total_equipos' => $total,
            'protocolos_seguros' => 0, // Placeholder if no explicit column
            'protocolos_inseguros' => 0,
            'last_updated' => date('Y-m-d H:i:s')
        ]);
    }
    elseif ($action === 'list') {
        // Paginacion y filtros
        $page = (int)($_GET['page'] ?? 1);
        $limit = (int)($_GET['limit'] ?? 10);
        $offset = ($page - 1) * $limit;
        
        $search = $_GET['search'] ?? '';
        
        $sql = "SELECT id, ip, hostname, mac, fabricante, created_at, updated_at FROM equipos";
        $params = [];
        
        if ($search) {
            $sql .= " WHERE hostname LIKE ? OR ip LIKE ?";
            $params[] = "%$search%";
            $params[] = "%$search%";
        }
        
        $sql .= " ORDER BY updated_at DESC LIMIT $limit OFFSET $offset";
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $devices = $stmt->fetchAll();
        
        echo json_encode(['data' => $devices, 'page' => $page]);
    }
    elseif ($action === 'details') {
        $id = $_GET['id'] ?? 0;
        $stmt = $pdo->prepare("SELECT * FROM equipos WHERE id = ?");
        $stmt->execute([$id]);
        $device = $stmt->fetch();
        
        // Fetch ports/protocols if related table exists
        // $stmtPorts = $pdo->prepare("SELECT * FROM puertos WHERE equipo_id = ?");
        // ...
        
        echo json_encode(['device' => $device]);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
