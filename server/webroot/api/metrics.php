<?php
// metrics.php - SSE Server-Sent Events CORREGIDO

require_once __DIR__ . '/../db_config.php';

// Validación de sesión MANUAL (sin check.php)
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

if (!isset($_SESSION['user_id'])) {
    // Para SSE, enviamos un evento de error y salimos
    header('Content-Type: text/event-stream');
    header('Cache-Control: no-cache');
    echo "event: error\n";
    echo "data: " . json_encode(['error' => 'Unauthorized']) . "\n\n";
    flush();
    exit;
}

// Headers SSE
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('X-Accel-Buffering: no'); // Para Nginx
ob_implicit_flush(true);
@ini_set('zlib.output_compression', 0);
@ini_set('implicit_flush', 1);

// Desactivar límites de tiempo para conexión larga
set_time_limit(0);
ignore_user_abort(false);

// Limpiar buffer de salida
while (ob_get_level() > 0) {
    ob_end_flush();
}
flush();

// ID del último evento (para re-conexión)
$lastEventId = intval(isset($_SERVER['HTTP_LAST_EVENT_ID']) ? $_SERVER['HTTP_LAST_EVENT_ID'] : 0);
$eventId = $lastEventId + 1;

// Contador de ciclos para evitar ejecución infinita
$maxCycles = 360; // Máximo 30 minutos (360 ciclos * 5 segundos)
$cycleCount = 0;

// Bucle principal de SSE
while ($cycleCount < $maxCycles) {
    // Verificar si el cliente se desconectó
    if (connection_aborted()) {
        error_log("SSE: Cliente desconectado");
        break;
    }
    
    try {
        // 1. Dispositivos activos (últimos 5 minutos)
        $stmtActive = $pdo->prepare("
            SELECT COUNT(*) as count 
            FROM equipos 
            WHERE ultima_deteccion >= NOW() - INTERVAL 5 MINUTE
        ");
        $stmtActive->execute();
        $activeDevices = $stmtActive->fetchColumn();
        
        // 2. Dispositivos totales
        $stmtTotal = $pdo->query("SELECT COUNT(*) FROM equipos");
        $totalDevices = $stmtTotal->fetchColumn();
        
        // 3. Conflictos no resueltos (si tienes tabla conflictos)
        $unresolvedConflicts = 0;
        try {
            $stmtConflicts = $pdo->query("SELECT COUNT(*) FROM conflictos WHERE estado = 'detectado'");
            $unresolvedConflicts = $stmtConflicts->fetchColumn();
        } catch (Exception $e) {
            // Tabla conflictos puede no existir
        }
        
        // 4. Último escaneo (timestamp más reciente)
        $stmtLastScan = $pdo->query("
            SELECT MAX(ultima_deteccion) as last_scan 
            FROM equipos 
            WHERE ultima_deteccion IS NOT NULL
        ");
        $lastScan = $stmtLastScan->fetchColumn();
        
        // Preparar datos
        $data = [
            'eventId' => $eventId,
            'timestamp' => date('Y-m-d H:i:s'),
            'active_devices' => (int)$activeDevices,
            'total_devices' => (int)$totalDevices,
            'unresolved_conflicts' => (int)$unresolvedConflicts,
            'last_scan' => $lastScan ? date('H:i:s', strtotime($lastScan)) : 'Nunca',
            'server_time' => date('H:i:s')
        ];
        
        // Enviar evento
        echo "id: " . $eventId . "\n";
        echo "event: update\n";
        echo "data: " . json_encode($data) . "\n\n";
        
        // Forzar envío inmediato
        if (ob_get_level() > 0) ob_flush();
        flush();
        
        // Incrementar IDs y contadores
        $eventId++;
        $cycleCount++;
        
    } catch (Exception $e) {
        // Enviar evento de error
        echo "event: error\n";
        echo "data: " . json_encode(['error' => 'Database error', 'message' => $e->getMessage()]) . "\n\n";
        flush();
        
        // Esperar antes de reintentar
        sleep(10);
        continue;
    }
    
    // Esperar 5 segundos antes del siguiente ciclo
    sleep(5);
}

// Evento de fin de conexión
if ($cycleCount >= $maxCycles) {
    echo "event: timeout\n";
    echo "data: " . json_encode(['message' => 'Connection timeout, reconnecting...']) . "\n\n";
    flush();
    sleep(1);
}

// Mensaje de cierre
echo "event: close\n";
echo "data: Connection closed\n\n";
flush();
exit;