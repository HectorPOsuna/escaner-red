<?php
/**
 * Seed OUI Script (PHP)
 */

require_once __DIR__ . '/../../server/db.php';

function seedOui() {
    echo "🌱 Sembrando Fabricantes (OUI)...\n";
    
    $ouiUrl = 'http://standards-oui.ieee.org/oui/oui.txt';
    $localFile = __DIR__ . '/oui.txt';

    // Descargar si no existe o es muy viejo (opcional, aquí simplificamos)
    if (!file_exists($localFile)) {
        echo "📥 Descargando lista OUI...\n";
        $content = file_get_contents($ouiUrl);
        if ($content === false) {
            echo "❌ Error descargando OUI.\n";
            return;
        }
        file_put_contents($localFile, $content);
    } else {
        echo "📂 Usando archivo OUI local.\n";
    }

    $handle = fopen($localFile, "r");
    if (!$handle) {
        echo "❌ No se pudo abrir el archivo OUI.\n";
        return;
    }

    $pdo = getDbConnection();
    $pdo->beginTransaction();

    try {
        $stmt = $pdo->prepare("INSERT IGNORE INTO fabricantes (nombre, oui_mac) VALUES (?, ?)");
        
        $count = 0;
        $batchSize = 1000;

        while (($line = fgets($handle)) !== false) {
            // Formato: 00-00-00   (hex)		XEROX CORPORATION
            if (preg_match('/^([0-9A-F]{2}-[0-9A-F]{2}-[0-9A-F]{2})\s+\(hex\)\s+(.+)$/i', $line, $matches)) {
                $oui = str_replace('-', '', $matches[1]); // 000000
                $name = trim($matches[2]);

                $stmt->execute([$name, $oui]);
                $count++;

                if ($count % $batchSize == 0) {
                    echo "\r⏳ Procesados: $count";
                    $pdo->commit();
                    $pdo->beginTransaction();
                }
            }
        }

        $pdo->commit();
        echo "\n✅ Sembrado de OUI completado. Total: $count\n";

    } catch (Exception $e) {
        $pdo->rollBack();
        echo "❌ Error durante el sembrado: " . $e->getMessage() . "\n";
    }

    fclose($handle);
}

// Ejecutar si se llama directamente
if (basename(__FILE__) == basename($_SERVER['PHP_SELF'])) {
    seedOui();
}
?>
