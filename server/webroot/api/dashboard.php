<?php
/**
 * dashboard.php - API para el Dashboard
 * Ubicación: /lisi3309/api/dashboard.php
 */

// Headers
header('Content-Type: application/json');
header('Access-Control-Allow-Credentials: true');

// Cargar configuración (dashboard.php está en /lisi3309/api/, db_config.php está en /lisi3309/)
require_once __DIR__ . '/../db_config.php';

// Verificar autenticación
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'error' => 'Unauthorized',
        'message' => 'Sesión no válida'
    ]);
    exit;
}

// Procesar acción
$action = $_GET['action'] ?? 'summary';

try {
    switch ($action) {
        case 'summary':
            // Estadísticas generales
            $stmt = $pdo->query("SELECT COUNT(*) as total FROM equipos");
            $total = (int)$stmt->fetchColumn();
            
            $stmt = $pdo->prepare("
                SELECT COUNT(*) as activos 
                FROM equipos 
                WHERE ultima_deteccion >= NOW() - INTERVAL 5 MINUTE
            ");
            $stmt->execute();
            $activos = (int)$stmt->fetchColumn();
            
            $stmt = $pdo->query("
                SELECT MAX(ultima_deteccion) as last_updated 
                FROM equipos
            ");
            $lastUpdated = $stmt->fetchColumn();
            
            echo json_encode([
                'success' => true,
                'total_equipos' => $total,
                'activos_5min' => $activos,
                'last_updated' => $lastUpdated
            ]);
            break;
            
        case 'list':
            // Listar dispositivos con paginación
            $limit = min(100, max(1, (int)($_GET['limit'] ?? 50)));
            $page = max(1, (int)($_GET['page'] ?? 1));
            $offset = ($page - 1) * $limit;
            $search = $_GET['search'] ?? '';
            
            // Construir query (solo columnas básicas que existen en la BD)
            $sql = "
                SELECT 
                    e.id_equipo,
                    e.hostname,
                    e.ip,
                    e.mac,
                    e.id_so,
                    e.ultima_deteccion,
                    e.fabricante_id,
                    so.nombre as so_nombre,
                    f.nombre as fabricante_nombre
                FROM equipos e
                LEFT JOIN sistemas_operativos so ON e.id_so = so.id_so
                LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
            ";
            
            $params = [];
            
            if (!empty($search)) {
                $sql .= " WHERE (
                    e.hostname LIKE ? OR 
                    e.ip LIKE ? OR 
                    e.mac LIKE ? OR
                    so.nombre LIKE ?
                )";
                $searchTerm = "%$search%";
                $params = [$searchTerm, $searchTerm, $searchTerm, $searchTerm];
            }
            
            $sql .= " ORDER BY e.ultima_deteccion DESC LIMIT ? OFFSET ?";
            $params[] = $limit;
            $params[] = $offset;
            
            $stmt = $pdo->prepare($sql);
            $stmt->execute($params);
            $devices = $stmt->fetchAll();
            
            // Contar total
            $countSql = "SELECT COUNT(*) FROM equipos e";
            if (!empty($search)) {
                $countSql .= " LEFT JOIN sistemas_operativos so ON e.id_so = so.id_so
                              WHERE (e.hostname LIKE ? OR e.ip LIKE ? OR e.mac LIKE ? OR so.nombre LIKE ?)";
                $countStmt = $pdo->prepare($countSql);
                $countStmt->execute([$searchTerm, $searchTerm, $searchTerm, $searchTerm]);
            } else {
                $countStmt = $pdo->query($countSql);
            }
            $total = (int)$countStmt->fetchColumn();
            
            echo json_encode([
                'success' => true,
                'data' => $devices,
                'page' => $page,
                'limit' => $limit,
                'total' => $total,
                'pages' => ceil($total / $limit)
            ]);
            break;
            
        case 'details':
            // Detalles de un dispositivo específico
            $id = (int)($_GET['id'] ?? 0);
            
            if ($id <= 0) {
                throw new Exception('ID inválido', 400);
            }
            
            // Obtener dispositivo
            $stmt = $pdo->prepare("
                SELECT 
                    e.*,
                    so.nombre as so_nombre,
                    f.nombre as fabricante_nombre
                FROM equipos e
                LEFT JOIN sistemas_operativos so ON e.id_so = so.id_so
                LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
                WHERE e.id_equipo = ?
            ");
            $stmt->execute([$id]);
            $device = $stmt->fetch();
            
            if (!$device) {
                throw new Exception('Dispositivo no encontrado', 404);
            }
            
            // Obtener puertos
            $stmt = $pdo->prepare("
                SELECT 
                    ep.puerto_numero,
                    ep.estado,
                    p.nombre as protocolo_nombre,
                    p.categoria
                FROM equipos_protocolos ep
                LEFT JOIN protocolos p ON ep.protocolo_id = p.id_protocolo
                WHERE ep.equipo_id = ?
            ");
            $stmt->execute([$id]);
            $ports = $stmt->fetchAll();
            
            echo json_encode([
                'success' => true,
                'device' => $device,
                'ports' => $ports
            ]);
            break;
            
        default:
            throw new Exception('Acción no válida', 400);
    }
    
} catch (Exception $e) {
    $code = $e->getCode() ?: 500;
    http_response_code($code);
    
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'code' => $code
    ]);
}