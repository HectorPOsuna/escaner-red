<?php
/**
 * Seed Protocolos Script (PHP)
 */

require_once __DIR__ . '/../../server/db.php';

function seedProtocolos() {
    echo "🌱 Sembrando Protocolos (IANA)...\n";
    
    $ianaUrl = 'https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.csv';
    $localFile = __DIR__ . '/service-names-port-numbers.csv';

    if (!file_exists($localFile)) {
        echo "📥 Descargando lista IANA...\n";
        $content = file_get_contents($ianaUrl);
        if ($content === false) {
            echo "❌ Error descargando IANA.\n";
            return;
        }
        file_put_contents($localFile, $content);
    } else {
        echo "📂 Usando archivo IANA local.\n";
    }

    $handle = fopen($localFile, "r");
    if (!$handle) {
        echo "❌ No se pudo abrir el archivo IANA.\n";
        return;
    }

    $pdo = getDbConnection();
    $pdo->beginTransaction();

    try {
        // Ignorar cabecera
        fgetcsv($handle);

        $stmt = $pdo->prepare("INSERT IGNORE INTO protocolos (numero, nombre, categoria, descripcion) VALUES (?, ?, ?, ?)");
        
        $count = 0;
        $batchSize = 1000;

        while (($data = fgetcsv($handle)) !== false) {
            // CSV: Service Name, Port Number, Transport Protocol, Description, ...
            $serviceName = $data[0] ?? '';
            $portNumber = $data[1] ?? '';
            $transport = $data[2] ?? '';
            $description = $data[3] ?? '';

            if (is_numeric($portNumber) && !empty($serviceName)) {
                // Simplificación: Solo TCP/UDP o el primero que venga
                // Categoría por defecto: 'otro'
                $categoria = 'otro';
                
                // Lógica simple de categorización
                if (in_array($portNumber, [80, 443, 8080])) $categoria = 'web';
                elseif (in_array($portNumber, [22, 3389])) $categoria = 'administracion';
                elseif (in_array($portNumber, [3306, 5432, 1433])) $categoria = 'base_de_datos';
                elseif (in_array($portNumber, [25, 110, 143, 587])) $categoria = 'correo';

                $stmt->execute([$portNumber, $serviceName, $categoria, substr($description, 0, 255)]);
                $count++;

                if ($count % $batchSize == 0) {
                    echo "\r⏳ Procesados: $count";
                    $pdo->commit();
                    $pdo->beginTransaction();
                }
            }
        }

        $pdo->commit();
        echo "\n✅ Sembrado de Protocolos completado. Total: $count\n";

    } catch (Exception $e) {
        $pdo->rollBack();
        echo "❌ Error durante el sembrado: " . $e->getMessage() . "\n";
    }

    fclose($handle);
}

// Ejecutar si se llama directamente
if (basename(__FILE__) == basename($_SERVER['PHP_SELF'])) {
    seedProtocolos();
}
?>
