<?php
/**
 * Metrics SSE - Simplificado
 */

// Headers primero, antes de cualquier output
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('Connection: keep-alive');
header('X-Accel-Buffering: no');

// Deshabilitar output buffering
@ini_set('output_buffering', 'off');
@ini_set('zlib.output_compression', 0);

// Limpiar cualquier buffer existente
while (ob_get_level() > 0) {
    ob_end_clean();
}

require_once __DIR__ . '/../db_config.php';

function sendSSE($data) {
    echo "data: " . json_encode($data) . "\n\n";
    if (ob_get_level() > 0) {
        ob_flush();
    }
    flush();
}

set_time_limit(0);
ignore_user_abort(false);

// Enviar comentario inicial para establecer conexión
echo ": connected\n\n";
flush();

while (true) {
    try {
        $stmt = $pdo->query("
            SELECT 
                COUNT(*) as total_equipos,
                SUM(CASE WHEN TIMESTAMPDIFF(MINUTE, ultima_deteccion, NOW()) <= 5 THEN 1 ELSE 0 END) as activos_5min
            FROM equipos
        ");
        $stats = $stmt->fetch(PDO::FETCH_ASSOC);
        
        sendSSE($stats);
        sleep(5);
        
        // Verificar si el cliente cerró la conexión
        if (connection_aborted()) {
            break;
        }
        
    } catch (Exception $e) {
        sendSSE(['error' => $e->getMessage()]);
        break;
    }
}