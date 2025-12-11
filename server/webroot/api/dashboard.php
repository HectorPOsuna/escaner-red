<?php
/**
 * Dashboard API - Simplificado
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Cache-Control: max-age=10');

require_once __DIR__ . '/../db_config.php';


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
            
        case 'devices':
            // Lista de dispositivos con información básica
            $page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
            $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 20;
            $offset = ($page - 1) * $limit;
            $search = $_GET['search'] ?? '';
            
            $sql = "SELECT 
                        e.id_equipo as id,
                        e.hostname,
                        e.ip,
                        e.mac,
                        e.ultima_deteccion,
                        so.nombre as so_nombre,
                        f.nombre as fabricante_nombre,
                        COUNT(DISTINCT pu.id_protocolo) as total_protocols
                    FROM equipos e
                    LEFT JOIN sistemas_operativos so ON e.id_so = so.id_so
                    LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
                    LEFT JOIN protocolos_usados pu ON e.id_equipo = pu.id_equipo";
            
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
            
            $sql .= " GROUP BY e.id_equipo ORDER BY e.ultima_deteccion DESC LIMIT ? OFFSET ?";
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
                    pu.puerto_detectado as puerto_numero,
                    pu.estado,
                    pu.fecha_hora,
                    p.nombre,
                    p.categoria
                FROM protocolos_usados pu
                INNER JOIN protocolos p ON pu.id_protocolo = p.id_protocolo
                WHERE pu.id_equipo = ?
                ORDER BY pu.puerto_detectado
            ");
            $stmt->execute([$id]);
            $ports = $stmt->fetchAll();
            
            echo json_encode([
                'success' => true,
                'device' => $device,
                'ports' => $ports
            ]);
            break;
            
        case 'protocol_stats':
            // Estadísticas de protocolos por categoría - CONTAR PROTOCOLOS ÚNICOS (Lógica PHP mejorada)
            try {
                // Obtener todos los protocolos usados y sus categorías
                $stmt = $pdo->query("
                    SELECT DISTINCT
                        p.id_protocolo,
                        p.categoria
                    FROM protocolos_usados pu
                    INNER JOIN protocolos p ON pu.id_protocolo = p.id_protocolo
                    WHERE p.categoria IS NOT NULL
                ");
                
                $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
                
                $stats = [];
                $total = 0;
                
                // Inicializar categorías conocidas para asegurar consistencia
                $categorias_contador = [];
                
                foreach ($rows as $row) {
                    $cat = $row['categoria'];
                    if (!isset($categorias_contador[$cat])) {
                        $categorias_contador[$cat] = 0;
                    }
                    $categorias_contador[$cat]++;
                    $total++;
                }
                
                // Formatear stats
                foreach ($categorias_contador as $cat => $count) {
                    $stats[$cat] = [
                        'count' => $count,
                        'percentage' => $total > 0 ? round(($count / $total) * 100, 1) : 0
                    ];
                }
                
                // Separar seguros vs inseguros
                $secureCount = 0;
                $insecureCount = 0;
                
                foreach ($stats as $cat => $data) {
                    if ($cat === 'inseguro') {
                        $insecureCount += $data['count'];
                    } else {
                        $secureCount += $data['count'];
                    }
                }
                
                echo json_encode([
                    'success' => true,
                    'categories' => $stats,
                    'totals' => [
                        'secure' => $secureCount,
                        'insecure' => $insecureCount,
                        'total' => $total
                    ]
                ]);
                
            } catch (Exception $e) {
                http_response_code(500);
                echo json_encode([
                    'success' => false,
                    'error' => 'Error en protocol_stats: ' . $e->getMessage()
                ]);
            }
            break;

        case 'category_device_stats':
            // Estadísticas agrupadas por categoría: Conteo de dispositivos únicos por categoría
            try {
                $stmt = $pdo->query("
                    SELECT 
                        p.categoria,
                        COUNT(DISTINCT pu.id_protocolo) as unique_protocol_count
                    FROM protocolos_usados pu
                    INNER JOIN protocolos p ON pu.id_protocolo = p.id_protocolo
                    WHERE p.categoria IS NOT NULL
                    GROUP BY p.categoria
                    ORDER BY unique_protocol_count DESC, p.categoria ASC
                ");
                
                $stats = $stmt->fetchAll(PDO::FETCH_ASSOC);
                
                echo json_encode([
                    'success' => true,
                    'stats' => $stats
                ]);
            } catch (Exception $e) {
                http_response_code(500);
                echo json_encode(['success' => false, 'error' => $e->getMessage()]);
            }
            break;

        case 'devices_by_protocol':
            // Dispositivos que usan un protocolo específico
            try {
                $protocolId = (int)($_GET['protocol_id'] ?? 0);
                if ($protocolId <= 0) throw new Exception('ID de protocolo inválido');
                
                $stmt = $pdo->prepare("
                    SELECT 
                        e.id_equipo,
                        e.hostname,
                        e.ip,
                        e.mac,
                        pu.fecha_hora as detection_time,
                        f.nombre as manufacturer
                    FROM protocolos_usados pu
                    INNER JOIN equipos e ON pu.id_equipo = e.id_equipo
                    LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
                    WHERE pu.id_protocolo = ?
                    ORDER BY e.ip ASC
                ");
                $stmt->execute([$protocolId]);
                $devices = $stmt->fetchAll(PDO::FETCH_ASSOC);
                
                // Obtener info del protocolo también
                $stmtProto = $pdo->prepare("SELECT nombre, numero, categoria FROM protocolos WHERE id_protocolo = ?");
                $stmtProto->execute([$protocolId]);
                $protocolInfo = $stmtProto->fetch(PDO::FETCH_ASSOC);
                
                echo json_encode([
                    'success' => true,
                    'protocol' => $protocolInfo,
                    'devices' => $devices
                ]);
            } catch (Exception $e) {
                http_response_code(500);
                echo json_encode(['success' => false, 'error' => $e->getMessage()]);
            }
            break;
            
        case 'protocol_details':
            // Obtener protocolos DETECTADOS de una categoría específica
            $categoria = $_GET['categoria'] ?? '';
            
            if (empty($categoria)) {
                throw new Exception('Categoría no especificada', 400);
            }
            
            $stmt = $pdo->prepare("
                SELECT DISTINCT
                    p.id_protocolo,
                    p.numero,
                    p.nombre,
                    p.categoria,
                    p.descripcion,
                    COUNT(DISTINCT pu.id_equipo) as dispositivos_usando
                FROM protocolos p
                INNER JOIN protocolos_usados pu ON p.id_protocolo = pu.id_protocolo
                WHERE p.categoria = ?
                GROUP BY p.id_protocolo, p.numero, p.nombre, p.categoria, p.descripcion
                ORDER BY p.nombre ASC
            ");
            $stmt->execute([$categoria]);
            $protocols = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'categoria' => $categoria,
                'protocols' => $protocols
            ]);
            break;

        case 'protocol_details_detailed':
            // Obtener protocolos CON DETALLE DE EQUIPOS de una categoría específica
            $categoria = $_GET['categoria'] ?? '';
            
            if (empty($categoria)) {
                throw new Exception('Categoría no especificada', 400);
            }
            
            $stmt = $pdo->prepare("
                SELECT 
                    p.id_protocolo,
                    p.numero,
                    p.nombre,
                    p.categoria,
                    p.descripcion,
                    e.hostname,
                    e.ip,
                    e.mac,
                    MAX(pu.fecha_hora) as last_scan
                FROM protocolos p
                INNER JOIN protocolos_usados pu ON p.id_protocolo = pu.id_protocolo
                INNER JOIN equipos e ON pu.id_equipo = e.id_equipo
                WHERE p.categoria = ?
                GROUP BY p.id_protocolo, e.id_equipo
                ORDER BY p.nombre ASC, e.ip ASC
            ");
            $stmt->execute([$categoria]);
            $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Agrupar por protocolo
            $protocolsMap = [];
            foreach ($rows as $row) {
                $pid = $row['id_protocolo'];
                if (!isset($protocolsMap[$pid])) {
                    $protocolsMap[$pid] = [
                        'id_protocolo' => $row['id_protocolo'],
                        'numero' => $row['numero'],
                        'nombre' => $row['nombre'],
                        'categoria' => $row['categoria'],
                        'descripcion' => $row['descripcion'],
                        'devices' => []
                    ];
                }
                $protocolsMap[$pid]['devices'][] = [
                    'hostname' => $row['hostname'],
                    'ip' => $row['ip'],
                    'mac' => $row['mac'],
                    'last_scan' => $row['last_scan']
                ];
            }
            
            echo json_encode([
                'success' => true,
                'categoria' => $categoria,
                'protocols' => array_values($protocolsMap)
            ]);
            break;
            
        case 'device_protocols':
            // Protocolos por dispositivo con clasificación seguro/inseguro
            $stmt = $pdo->query("
                SELECT 
                    e.id_equipo,
                    e.hostname,
                    e.ip,
                    COUNT(DISTINCT pu.id_protocolo) as total_protocols,
                    SUM(CASE WHEN p.categoria IN ('esencial', 'base_de_datos', 'archivos') THEN 1 ELSE 0 END) as secure_count,
                    SUM(CASE WHEN p.categoria = 'inseguro' THEN 1 ELSE 0 END) as insecure_count,
                    GROUP_CONCAT(DISTINCT p.nombre ORDER BY p.nombre SEPARATOR ', ') as protocols
                FROM equipos e
                LEFT JOIN protocolos_usados pu ON e.id_equipo = pu.id_equipo
                LEFT JOIN protocolos p ON pu.id_protocolo = p.id_protocolo
                GROUP BY e.id_equipo, e.hostname, e.ip
                HAVING total_protocols > 0
                ORDER BY total_protocols DESC
                LIMIT 20
            ");
            $devices = $stmt->fetchAll();
            
            // Convertir a formato adecuado
            $result = [];
            foreach ($devices as $device) {
                $result[] = [
                    'id' => (int)$device['id_equipo'],
                    'hostname' => $device['hostname'] ?: $device['ip'],
                    'ip' => $device['ip'],
                    'total_protocols' => (int)$device['total_protocols'],
                    'secure_count' => (int)$device['secure_count'],
                    'insecure_count' => (int)$device['insecure_count'],
                    'protocols' => $device['protocols']
                ];
            }
            
            echo json_encode([
                'success' => true,
                'devices' => $result,
                'total_devices' => count($result)
            ]);
            break;
            
        case 'protocol_devices':
            // Obtener dispositivos que usan una categoría específica de protocolo
            $category = $_GET['category'] ?? '';
            
            if (empty($category)) {
                throw new Exception('Categoría no especificada', 400);
            }
            
            $stmt = $pdo->prepare("
                SELECT DISTINCT
                    e.id_equipo,
                    e.hostname,
                    e.ip,
                    e.mac,
                    e.ultima_deteccion,
                    so.nombre as so_nombre,
                    f.nombre as fabricante_nombre,
                    GROUP_CONCAT(DISTINCT p.nombre ORDER BY p.nombre SEPARATOR ', ') as protocols,
                    GROUP_CONCAT(DISTINCT pu.puerto_detectado ORDER BY pu.puerto_detectado SEPARATOR ', ') as ports
                FROM equipos e
                INNER JOIN protocolos_usados pu ON e.id_equipo = pu.id_equipo
                INNER JOIN protocolos p ON pu.id_protocolo = p.id_protocolo
                LEFT JOIN sistemas_operativos so ON e.id_so = so.id_so
                LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
                WHERE p.categoria = ?
                GROUP BY e.id_equipo, e.hostname, e.ip, e.mac, e.ultima_deteccion, so.nombre, f.nombre
                ORDER BY e.hostname, e.ip
            ");
            $stmt->execute([$category]);
            $devices = $stmt->fetchAll();
            
            echo json_encode([
                'success' => true,
                'category' => $category,
                'devices' => $devices,
                'total' => count($devices)
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