<?php
/**
 * Cron Process Script
 * 
 * Uso: php cron_process.php
 * Descripción: Lee agent/scan_results.json y actualiza la base de datos.
 */

require_once 'ScanProcessor.php';

// Ruta al archivo JSON (ajustar según estructura)
$scanFile = __DIR__ . '/../agent/scan_results.json';

if (!file_exists($scanFile)) {
    // Silencioso si no hay archivo, para no llenar logs de cron
    exit(0);
}

echo "----------------------------------------------------------------\n";
echo "🕒 Inicio de procesamiento: " . date('Y-m-d H:i:s') . "\n";
echo "📄 Archivo detectado: $scanFile\n";

try {
    $jsonContent = file_get_contents($scanFile);
    $scanData = json_decode($jsonContent, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception("Error decodificando JSON: " . json_last_error_msg());
    }

    $processor = new ScanProcessor();
    $results = $processor->processScanData($scanData);

    echo "✅ Procesamiento completado.\n";
    echo "   - Procesados: {$results['processed']}\n";
    echo "   - Conflictos: {$results['conflicts']}\n";
    echo "   - Errores:    {$results['errors']}\n";

    // Renombrar archivo procesado
    $processedFile = $scanFile . '.processed';
    if (rename($scanFile, $processedFile)) {
        echo "🗑️  Archivo renombrado a: $processedFile\n";
    } else {
        echo "⚠️  No se pudo renombrar el archivo.\n";
    }

} catch (Exception $e) {
    echo "❌ Error fatal: " . $e->getMessage() . "\n";
    exit(1);
}

echo "🏁 Fin de ejecución: " . date('Y-m-d H:i:s') . "\n";
echo "----------------------------------------------------------------\n";
?>
