<?php
require_once __DIR__ . '/../db_config.php';

// SSE Headers
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('Connection: keep-alive');

// Optional: Auth Check (might require passing session ID in query param for SSE if cookies are strict)
// For simplicity/browser-support, we assume cookie auth works if same-origin.
if (session_status() === PHP_SESSION_NONE) session_start();
if (!isset($_SESSION['user_id'])) {
    echo "event: error\n";
    echo "data: Unauthorized\n\n";
    flush();
    exit;
}

// Loop for sending events
// In production, keep this strictly controlled or use a proper push service to avoid holding PHP threads.
// For this demo/requirement, we'll send one update or loop briefly.
// A common pattern in standard PHP (Apache/CGI) is NOT to loop infinitely to avoid timeout/resource limit.
// Better: Client polls this or connects, gets data, and connection closes if server times out.
// Or usage of specific event loop. We will implement "One-shot" or "Short-burst" logic for compatibility.

// Actually, SSE implies long-running. Basic PHP might be killed by execution_time limit.
set_time_limit(0); 

$lastId = 0;

while (true) {
    // Check connection status
    if (connection_aborted()) break;

    // Fetch Metrics
    // Example: Count of active devices in last minute
    try {
        // Query recent updates
        $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM equipos WHERE updated_at >= NOW() - INTERVAL 1 MINUTE");
        $stmt->execute();
        $activeNow = $stmt->fetchColumn();

        $data = json_encode([
            'time' => date('H:i:s'),
            'active_devices' => $activeNow,
            'cpu_load' => sys_getloadavg()[0] ?? 0 // if linux
        ]);

        echo "id: " . time() . "\n";
        echo "data: {$data}\n\n";
        
        ob_flush();
        flush();
    } catch (Exception $e) {
        // Silent fail or send error event
    }

    // Wait 5 seconds
    sleep(5);
}
