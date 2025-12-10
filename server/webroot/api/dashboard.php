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
        
        // Count active devices (last 5 minutes)
        $activeCount = $pdo->query("SELECT COUNT(*) FROM equipos WHERE ultima_deteccion >= NOW() - INTERVAL 5 MINUTE")->fetchColumn();
        
        echo json_encode([
            'success' => true,
            'total_equipos' => (int)$total,
            'activos_5min' => (int)$activeCount,
            'last_updated' => date('Y-m-d H:i:s')
        ]);
        exit;
    }
    elseif ($action === 'list') {
        // Paginacion y filtros
        $page = (int)($_GET['page'] ?? 1);
        $limit = (int)($_GET['limit'] ?? 10);
        $offset = ($page - 1) * $limit;
        
        $search = $_GET['search'] ?? '';
        
        $sql = "SELECT e.*, f.nombre as fabricante_nombre 
                FROM equipos e 
                LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante";
        $params = [];
        
        if ($search) {
            $sql .= " WHERE e.hostname LIKE ? OR e.ip LIKE ? OR e.mac LIKE ?";
            $params[] = "%$search%";
            $params[] = "%$search%";
            $params[] = "%$search%";
        }
        
        $sql .= " ORDER BY e.ultima_deteccion DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $devices = $stmt->fetchAll();
        
        // Get total count for pagination
        $countSql = "SELECT COUNT(*) FROM equipos e";
        if ($search) {
            $countSql .= " WHERE e.hostname LIKE ? OR e.ip LIKE ? OR e.mac LIKE ?";
        }
        $countStmt = $pdo->prepare($countSql);
        $countStmt->execute($search ? ["%$search%", "%$search%", "%$search%"] : []);
        $total = $countStmt->fetchColumn();
        
        echo json_encode([
            'success' => true,
            'data' => $devices,
            'page' => $page,
            'limit' => $limit,
            'total' => (int)$total,
            'pages' => ceil($total / $limit)
        ]);
        exit;
    }
    elseif ($action === 'details') {
        $id = $_GET['id'] ?? 0;
        $stmt = $pdo->prepare("
            SELECT e.*, f.nombre as fabricante_nombre, so.nombre as so_nombre 
            FROM equipos e 
            LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
            LEFT JOIN sistemas_operativos so ON e.id_so = so.id_so 
            WHERE e.id_equipo = ?
        ");
        $stmt->execute([$id]);
        $device = $stmt->fetch();
        
        if (!$device) {
            echo json_encode(['success' => false, 'message' => 'Device not found']);
            exit;
        }
        
        echo json_encode(['success' => true, 'device' => $device]);
        exit;
    }
    else {
        echo json_encode(['success' => false, 'message' => 'Invalid action']);
        exit;
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    exit;
}