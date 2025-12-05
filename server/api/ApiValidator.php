<?php
/**
 * API Validator
 * Valida y sanitiza datos recibidos de agentes externos
 */

class ApiValidator {
    private $errors = [];

    /**
     * Valida el payload completo del escaneo
     */
    public function validateScanPayload($data) {
        $this->errors = [];

        // Validar estructura básica
        if (!isset($data['Devices']) || !is_array($data['Devices'])) {
            $this->errors[] = "Campo 'Devices' requerido y debe ser un array";
            return false;
        }

        // Validar que no esté vacío
        if (empty($data['Devices'])) {
            $this->errors[] = "El array 'Devices' no puede estar vacío";
            return false;
        }

        // Validar cada dispositivo
        foreach ($data['Devices'] as $index => $device) {
            $this->validateDevice($device, $index);
        }

        return empty($this->errors);
    }

    /**
     * Valida un dispositivo individual
     */
    private function validateDevice($device, $index) {
        // IP es obligatoria
        if (!isset($device['IP']) || empty($device['IP'])) {
            $this->errors[] = "Dispositivo #$index: IP es requerida";
        } elseif (!filter_var($device['IP'], FILTER_VALIDATE_IP)) {
            $this->errors[] = "Dispositivo #$index: IP '{$device['IP']}' no es válida";
        }

        // MAC es opcional pero debe tener formato válido si existe
        if (isset($device['MAC']) && !empty($device['MAC'])) {
            if (!$this->isValidMac($device['MAC'])) {
                $this->errors[] = "Dispositivo #$index: MAC '{$device['MAC']}' no es válida";
            }
        }

        // Hostname es opcional
        // OpenPorts es opcional
    }

    /**
     * Valida formato de dirección MAC
     */
    private function isValidMac($mac) {
        // Acepta formatos: XX:XX:XX:XX:XX:XX o XX-XX-XX-XX-XX-XX
        return preg_match('/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/', $mac);
    }

    /**
     * Normaliza el payload al formato interno
     */
    public function normalizePayload($data) {
        $normalized = [
            'scan_timestamp' => date('Y-m-d\TH:i:s'),
            'subnet' => $this->inferSubnet($data['Devices']),
            'hosts' => []
        ];

        foreach ($data['Devices'] as $device) {
            $host = [
                'ip' => $device['IP'],
                'mac' => $device['MAC'] ?? null,
                'hostname' => $device['Hostname'] ?? 'Desconocido',
                'manufacturer' => 'Desconocido',
                'os' => 'Unknown',
                'open_ports' => $this->parseOpenPorts($device['OpenPorts'] ?? '')
            ];

            $normalized['hosts'][] = $host;
        }

        return $normalized;
    }

    /**
     * Parsea puertos abiertos desde string o array
     */
    private function parseOpenPorts($openPorts) {
        if (empty($openPorts)) {
            return [];
        }

        // Si ya es un array, retornarlo
        if (is_array($openPorts)) {
            return $openPorts;
        }

        // Si es string, parsear (formato: "80,443,3306" o "80, 443, 3306")
        $ports = [];
        $portList = explode(',', $openPorts);
        
        foreach ($portList as $port) {
            $port = trim($port);
            if (is_numeric($port)) {
                $ports[] = [
                    'port' => (int)$port,
                    'protocol' => 'Unknown',
                    'detected_at' => date('H:i:s')
                ];
            }
        }

        return $ports;
    }

    /**
     * Infiere la subred desde las IPs
     */
    private function inferSubnet($devices) {
        if (empty($devices)) {
            return '0.0.0.0/24';
        }

        $firstIp = $devices[0]['IP'] ?? '0.0.0.0';
        $parts = explode('.', $firstIp);
        
        if (count($parts) === 4) {
            return "{$parts[0]}.{$parts[1]}.{$parts[2]}.0/24";
        }

        return '0.0.0.0/24';
    }

    /**
     * Obtiene los errores de validación
     */
    public function getErrors() {
        return $this->errors;
    }

    /**
     * Obtiene el primer error
     */
    public function getFirstError() {
        return $this->errors[0] ?? 'Error desconocido';
    }
}
?>
