<?php
require_once 'db.php';

class ScanProcessor {
    private $pdo;

    public function __construct() {
        $this->pdo = getDbConnection();
    }

    public function processScanData($scanData) {
        $hosts = $scanData['hosts'] ?? [];
        $subnet = $scanData['subnet'] ?? '';

        if (!is_array($hosts)) {
            throw new Exception("Invalid payload format");
        }

        echo "📥 Procesando datos de escaneo: " . count($hosts) . " hosts. Subnet: $subnet\n";

        $results = [
            'processed' => 0,
            'conflicts' => 0,
            'errors' => 0
        ];

        foreach ($hosts as $host) {
            try {
                // 1. Validación de Conflictos
                $this->detectConflicts($host, $results);

                // 2. Persistencia de Datos
                $this->persistHost($host);

                $results['processed']++;

            } catch (Exception $e) {
                echo "❌ Error procesando host {$host['ip']}: " . $e->getMessage() . "\n";
                $results['errors']++;
            }
        }

        return $results;
    }

    private function detectConflicts($host, &$results) {
        $ip = $host['ip'] ?? null;
        $mac = $host['mac'] ?? null;
        $hostname = $host['hostname'] ?? null;

        // A) Conflicto de IP
        if ($ip) {
            $existingIp = $this->getEquipoByIp($ip);
            if ($existingIp) {
                if ($mac && $existingIp['mac'] && $mac !== $existingIp['mac']) {
                    $this->registerConflict([
                        'ip' => $ip,
                        'mac' => $mac,
                        'hostname' => $hostname,
                        'description' => "Conflicto de IP: La IP $ip está asignada a {$existingIp['hostname']} ({$existingIp['mac']}) pero fue detectada en $hostname ($mac)"
                    ]);
                    $results['conflicts']++;
                } elseif ($hostname && $existingIp['hostname'] && $hostname !== $existingIp['hostname']) {
                    if (!$mac || !$existingIp['mac'] || $mac !== $existingIp['mac']) {
                        $this->registerConflict([
                            'ip' => $ip,
                            'mac' => $mac,
                            'hostname' => $hostname,
                            'description' => "Conflicto de Hostname en IP: La IP $ip cambió de {$existingIp['hostname']} a $hostname sin validación de MAC."
                        ]);
                        $results['conflicts']++;
                    }
                }
            }
        }

        // B) Conflicto de MAC
        if ($mac) {
            $existingMac = $this->getEquipoByMac($mac);
            if ($existingMac) {
                if ($hostname && $existingMac['hostname'] && $hostname !== $existingMac['hostname']) {
                    $this->registerConflict([
                        'ip' => $ip,
                        'mac' => $mac,
                        'hostname' => $hostname,
                        'description' => "Conflicto de MAC: El dispositivo $mac cambió de nombre de {$existingMac['hostname']} a $hostname"
                    ]);
                    $results['conflicts']++;
                }
            }
        }

        // C) Conflicto de Hostname (Simplificado para brevedad)
        // ... (Implementar lógica similar si es crítico)
    }

    private function persistHost($host) {
        $ip = $host['ip'] ?? null;
        $mac = $host['mac'] ?? null;
        $hostname = $host['hostname'] ?? 'Desconocido';
        $os = $host['os'] ?? 'Unknown';
        $manufacturer = $host['manufacturer'] ?? 'Desconocido';

        // a) Fabricante
        $fabricanteId = null;
        $oui = null;

        if ($mac) {
            $oui = strtoupper(substr(str_replace([':', '-'], '', $mac), 0, 6));
            $fabricanteDb = $this->getFabricanteByOui($oui);
            if ($fabricanteDb) {
                $fabricanteId = $fabricanteDb['id_fabricante'];
            }
        }

        if (!$fabricanteId && $manufacturer !== 'Desconocido') {
            $fabricanteId = $this->createFabricante($manufacturer, $oui ?: '000000');
        }

        // b) Equipo
        // Obtener ID de SO
        $soId = $this->getOrCreateSistemaOperativo($os);

        $equipoId = $this->upsertEquipo([
            'hostname' => $hostname,
            'ip' => $ip,
            'mac' => $mac,
            'id_so' => $soId,
            'fabricante_id' => $fabricanteId ?: 1 // 1 = Desconocido (según seed)
        ]);

        // c) Protocolos
        if (isset($host['open_ports']) && is_array($host['open_ports'])) {
            foreach ($host['open_ports'] as $portInfo) {
                $port = $portInfo['port'];
                $protocolName = $portInfo['protocol'] ?? 'Unknown';

                $protocoloId = null;
                $existingProtocol = $this->getProtocoloByPort($port);

                if ($existingProtocol) {
                    $protocoloId = $existingProtocol['id_protocolo'];
                } else {
                    $protocoloId = $this->createProtocolo($port, $protocolName, 'otro');
                }

                if ($protocoloId) {
                    $this->registerProtocolUse($equipoId, $protocoloId, $port);
                }
            }
        }
    }

    // --- Helpers de Base de Datos ---

    private function getEquipoByIp($ip) {
        $stmt = $this->pdo->prepare("SELECT * FROM equipos WHERE ip = ?");
        $stmt->execute([$ip]);
        return $stmt->fetch();
    }

    private function getEquipoByMac($mac) {
        $stmt = $this->pdo->prepare("SELECT * FROM equipos WHERE mac = ?");
        $stmt->execute([$mac]);
        return $stmt->fetch();
    }

    private function registerConflict($data) {
        $stmt = $this->pdo->prepare("INSERT INTO conflictos (ip, mac, hostname_conflictivo, descripcion, estado, fecha_detectado) VALUES (?, ?, ?, ?, 'detectado', NOW())");
        $stmt->execute([$data['ip'], $data['mac'], $data['hostname'], $data['description']]);
    }

    private function getFabricanteByOui($oui) {
        $stmt = $this->pdo->prepare("SELECT * FROM fabricantes WHERE oui_mac = ?");
        $stmt->execute([$oui]);
        return $stmt->fetch();
    }

    private function createFabricante($nombre, $oui) {
        $stmt = $this->pdo->prepare("INSERT INTO fabricantes (nombre, oui_mac) VALUES (?, ?)");
        try {
            $stmt->execute([$nombre, $oui]);
            return $this->pdo->lastInsertId();
        } catch (PDOException $e) {
            // Si falla por duplicado, intentar recuperar
            return $this->getFabricanteByOui($oui)['id_fabricante'] ?? 1;
        }
    }

    private function getOrCreateSistemaOperativo($nombre) {
        $stmt = $this->pdo->prepare("SELECT id_so FROM sistemas_operativos WHERE nombre = ?");
        $stmt->execute([$nombre]);
        $row = $stmt->fetch();
        if ($row) return $row['id_so'];

        $stmt = $this->pdo->prepare("INSERT INTO sistemas_operativos (nombre) VALUES (?)");
        try {
            $stmt->execute([$nombre]);
            return $this->pdo->lastInsertId();
        } catch (PDOException $e) {
            return $this->getOrCreateSistemaOperativo($nombre);
        }
    }

    private function upsertEquipo($data) {
        // Buscar si existe por IP o MAC para actualizar, o insertar nuevo
        // Lógica simplificada: ON DUPLICATE KEY UPDATE basado en IP (Unique)
        // Nota: La tabla tiene UNIQUE(ip) y UNIQUE(mac). Esto puede ser complejo.
        // Estrategia: Intentar UPDATE por IP, si no afecta filas, INSERT.
        
        // Primero intentamos buscar por IP
        $existing = $this->getEquipoByIp($data['ip']);
        
        if ($existing) {
            $stmt = $this->pdo->prepare("UPDATE equipos SET hostname = ?, mac = ?, id_so = ?, fabricante_id = ?, ultima_deteccion = NOW() WHERE ip = ?");
            $stmt->execute([$data['hostname'], $data['mac'], $data['id_so'], $data['fabricante_id'], $data['ip']]);
            return $existing['id_equipo'];
        } else {
            // Si no existe por IP, intentamos insertar. Si falla por MAC duplicada, actualizamos esa MAC.
            try {
                $stmt = $this->pdo->prepare("INSERT INTO equipos (hostname, ip, mac, id_so, fabricante_id, ultima_deteccion) VALUES (?, ?, ?, ?, ?, NOW())");
                $stmt->execute([$data['hostname'], $data['ip'], $data['mac'], $data['id_so'], $data['fabricante_id']]);
                return $this->pdo->lastInsertId();
            } catch (PDOException $e) {
                if ($e->getCode() == 23000 && strpos($e->getMessage(), 'mac') !== false) {
                    // Conflicto de MAC: Actualizar el equipo que tiene esa MAC con la nueva IP
                    $stmt = $this->pdo->prepare("UPDATE equipos SET hostname = ?, ip = ?, id_so = ?, fabricante_id = ?, ultima_deteccion = NOW() WHERE mac = ?");
                    $stmt->execute([$data['hostname'], $data['ip'], $data['id_so'], $data['fabricante_id'], $data['mac']]);
                    return $this->getEquipoByMac($data['mac'])['id_equipo'];
                }
                throw $e;
            }
        }
    }

    private function getProtocoloByPort($port) {
        $stmt = $this->pdo->prepare("SELECT * FROM protocolos WHERE numero = ? LIMIT 1");
        $stmt->execute([$port]);
        return $stmt->fetch();
    }

    private function createProtocolo($port, $nombre, $categoria) {
        $stmt = $this->pdo->prepare("INSERT INTO protocolos (numero, nombre, categoria, descripcion) VALUES (?, ?, ?, 'Auto-detected')");
        try {
            $stmt->execute([$port, $nombre, $categoria]);
            return $this->pdo->lastInsertId();
        } catch (PDOException $e) {
            return $this->getProtocoloByPort($port)['id_protocolo'] ?? null;
        }
    }

    private function registerProtocolUse($equipoId, $protocoloId, $port) {
        // Insertar o actualizar fecha
        $stmt = $this->pdo->prepare("INSERT INTO protocolos_usados (id_equipo, id_protocolo, puerto_detectado, fecha_hora, estado) VALUES (?, ?, ?, NOW(), 'activo') ON DUPLICATE KEY UPDATE fecha_hora = NOW()");
        $stmt->execute([$equipoId, $protocoloId, $port]);
    }
}
?>
