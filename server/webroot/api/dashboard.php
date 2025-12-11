<?php
/**
 * API REST - Dashboard (Consultas)
 */
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

// Incluir configuración de DB (Ajustado para server/webroot/api/dashboard.php)
// server/webroot/api/dashboard.php (0)
// server/webroot/api (1)
// server/webroot (2)
// server (3)
// ../../../db_config.php targets server/../db_config.php i.e. root/db_config.php
require_once __DIR__ . '/../db_config.php';

$action = $_GET['action'] ?? '';

// Helpers
function sendJson($success, $data = [], $msg = '') {
    echo json_encode(['success' => $success, 'message' => $msg] + $data);
    exit;
}

try {
    switch ($action) {
        
        case 'stats': // Estadísticas generales
            // Total Equipos
            $stmt = $pdo->query("SELECT COUNT(*) as total FROM equipos");
            $total = $stmt->fetchColumn();

            // Activos (últimos 5 min)
            $stmt = $pdo->query("SELECT COUNT(*) as activos FROM equipos WHERE ultima_deteccion >= NOW() - INTERVAL 5 MINUTE");
            $activos = $stmt->fetchColumn();
            
            // Protocolos Únicos (Instancias de servicios activos)
            $stmt = $pdo->query("SELECT COUNT(DISTINCT id_equipo, id_protocolo) as protocolos FROM protocolos_usados WHERE estado = 'activo'");
            $protos = $stmt->fetchColumn();

            sendJson(true, ['stats' => [
                'total_equipos' => $total,
                'activos_5min' => $activos,
                'protocolos_detectados' => $protos
            ]]);
            break;

        case 'protocol_stats': // Datos para gráficas
            // Totales por categoría (Instancias únicas)
            $sql = "SELECT p.categoria, COUNT(DISTINCT pu.id_equipo, pu.id_protocolo) as count 
                    FROM protocolos_usados pu 
                    JOIN protocolos p ON pu.id_protocolo = p.id_protocolo 
                    WHERE pu.estado = 'activo'
                    GROUP BY p.categoria";
            $stmt = $pdo->query($sql);
            $cats = $stmt->fetchAll(PDO::FETCH_KEY_PAIR); // categoria => count

            // Total y Seguros
            $total = array_sum($cats);
            $secure = $cats['seguro'] ?? 0;

            sendJson(true, [
                'totals' => ['total' => $total, 'secure' => $secure],
                'categories' => array_map(function($c) { return ['count' => $c]; }, $cats)
            ]);
            break;
            
        case 'category_device_stats': // Para gráfica de barras (Top Categorías/Dispositivos)
             $sql = "SELECT p.categoria, COUNT(DISTINCT pu.id_equipo) as unique_device_count, COUNT(DISTINCT pu.id_protocolo) as unique_protocol_count
                    FROM protocolos_usados pu 
                    JOIN protocolos p ON pu.id_protocolo = p.id_protocolo 
                    WHERE pu.estado = 'activo'
                    GROUP BY p.categoria
                    ORDER BY unique_device_count DESC LIMIT 10";
            $stmt = $pdo->query($sql);
            $stats = $stmt->fetchAll(PDO::FETCH_ASSOC);
            sendJson(true, ['stats' => $stats]);
            break;

        case 'devices': // Lista de dispositivos (Tabla)
            $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;
            
            $sql = "SELECT e.id_equipo, e.hostname, e.ip, e.mac, e.ultima_deteccion,
                           so.nombre as so_nombre, f.nombre as fabricante_nombre,
                           (SELECT COUNT(DISTINCT id_protocolo) FROM protocolos_usados WHERE id_equipo = e.id_equipo AND estado='activo') as total_protocols
                    FROM equipos e
                    LEFT JOIN sistemas_operativos so ON e.id_so = so.id_so
                    LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
                    ORDER BY e.ultima_deteccion DESC
                    LIMIT $limit";
            
            $stmt = $pdo->query($sql);
            $devices = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            sendJson(true, ['data' => $devices]);
            break;
            
        case 'details': // Detalles de un dispositivo específico
            $id = $_GET['id'] ?? 0;
            if (!$id) sendJson(false, [], 'ID requerido');

            // Info básica
            $stmt = $pdo->prepare("SELECT e.*, so.nombre as so_nombre, f.nombre as fabricante_nombre 
                                   FROM equipos e 
                                   LEFT JOIN sistemas_operativos so ON e.id_so = so.id_so
                                   LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
                                   WHERE e.id_equipo = ?");
            $stmt->execute([$id]);
            $device = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$device) sendJson(false, [], 'Dispositivo no encontrado');

            // Puertos
            $sqlPorts = "SELECT pu.puerto_detectado as puerto_numero, p.nombre, p.categoria, pu.estado, pu.fecha_hora 
                         FROM protocolos_usados pu
                         JOIN protocolos p ON pu.id_protocolo = p.id_protocolo
                         WHERE pu.id_equipo = ?
                         ORDER BY pu.puerto_detectado ASC";
            $stmtP = $pdo->prepare($sqlPorts);
            $stmtP->execute([$id]);
            $ports = $stmtP->fetchAll(PDO::FETCH_ASSOC);

            sendJson(true, ['device' => $device, 'ports' => $ports]);
            break;

        case 'protocol_details': // Detalles de protocolos por categoría (Lista simple)
            $cat = $_GET['categoria'] ?? '';
            if (!$cat) sendJson(false, [], 'Categoría requerida');

            $sql = "SELECT p.id_protocolo, p.nombre, p.numero, p.categoria, p.descripcion, 
                           COUNT(DISTINCT pu.id_equipo) as dispositivos_usando
                    FROM protocolos p
                    LEFT JOIN protocolos_usados pu ON p.id_protocolo = pu.id_protocolo AND pu.estado = 'activo'
                    WHERE p.categoria = ?
                    GROUP BY p.id_protocolo
                    HAVING dispositivos_usando > 0
                    ORDER BY p.numero ASC";
            
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$cat]);
            $protocols = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            sendJson(true, ['protocols' => $protocols]);
            break;

        case 'protocol_details_detailed': // Detalles completos con lista de equipos
            $cat = $_GET['categoria'] ?? '';
            if (!$cat) sendJson(false, [], 'Categoría requerida');

            // 1. Obtener protocolos de la categoría
            $sql = "SELECT p.id_protocolo, p.nombre, p.numero, p.categoria, p.descripcion
                    FROM protocolos p 
                    JOIN protocolos_usados pu ON p.id_protocolo = pu.id_protocolo
                    WHERE p.categoria = ? AND pu.estado = 'activo'
                    GROUP BY p.id_protocolo
                    ORDER BY p.numero ASC";

            $stmt = $pdo->prepare($sql);
            $stmt->execute([$cat]);
            $protocols = $stmt->fetchAll(PDO::FETCH_ASSOC);

            // 2. Para cada protocolo, obtener los dispositivos recientes
            foreach ($protocols as &$p) {
                $sqlDev = "SELECT e.hostname, e.ip, e.mac, MAX(pu.fecha_hora) as last_scan
                           FROM equipos e
                           JOIN protocolos_usados pu ON e.id_equipo = pu.id_equipo
                           WHERE pu.id_protocolo = ? AND pu.estado = 'activo'
                           GROUP BY e.id_equipo, e.hostname, e.ip, e.mac
                           ORDER BY last_scan DESC
                           LIMIT 20"; // Limitar a 20 por protocolo para no saturar
                $stmtDev = $pdo->prepare($sqlDev);
                $stmtDev->execute([$p['id_protocolo']]);
                $p['devices'] = $stmtDev->fetchAll(PDO::FETCH_ASSOC);
            }

            sendJson(true, ['protocols' => $protocols]);
            break;

        case 'export_data': // Datasets completos para PDF/CSV con historial de puertos
            $sql = "SELECT 
                        e.hostname, 
                        e.ip, 
                        e.mac, 
                        e.ultima_deteccion as last_seen,
                        IFNULL(so.nombre, 'Desconocido') as os, 
                        IFNULL(f.nombre, 'Desconocido') as manufacturer,
                        (
                            SELECT GROUP_CONCAT(CONCAT(p.numero, '/', p.nombre, ' (', DATE_FORMAT(pu.fecha_hora, '%d/%m %H:%i'), ')') SEPARATOR '\n')
                            FROM protocolos_usados pu
                            JOIN protocolos p ON pu.id_protocolo = p.id_protocolo
                            WHERE pu.id_equipo = e.id_equipo AND pu.estado = 'activo'
                        ) as ports_details
                    FROM equipos e
                    LEFT JOIN sistemas_operativos so ON e.id_so = so.id_so
                    LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
                    ORDER BY e.ultima_deteccion DESC";
            
            $stmt = $pdo->query($sql);
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
            sendJson(true, ['data' => $data]);
            break;

        case 'get_conflicts': // Obtener lista de conflictos
            $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;
            $stmt = $pdo->query("SELECT * FROM conflictos ORDER BY fecha_detectado DESC LIMIT $limit");
            $conflictos = $stmt->fetchAll(PDO::FETCH_ASSOC);
            sendJson(true, ['data' => $conflictos]);
            break;

        default:
            sendJson(false, [], 'Acción inválida');
    }

} catch (PDOException $e) {
    http_response_code(500);
    sendJson(false, [], 'Error BD: ' . $e->getMessage());
}