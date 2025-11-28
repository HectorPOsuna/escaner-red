-- ==============================================================================
-- Tabla: conflictos
-- Descripción: Registra conflictos de red detectados en el sistema de monitoreo
--              Incluye IP duplicadas, MAC duplicadas y asignaciones incorrectas
-- Motor: InnoDB para soporte de transacciones y claves foráneas
-- Charset: utf8mb4 para compatibilidad completa con Unicode
-- ==============================================================================

CREATE TABLE IF NOT EXISTS conflictos (
    -- Identificador único del conflicto
    id_conflicto INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Dirección IP involucrada en el conflicto (soporta IPv4 e IPv6)
    ip VARCHAR(45) NULL COMMENT 'Dirección IP del conflicto (IPv4 o IPv6)',
    
    -- Dirección MAC involucrada en el conflicto
    mac VARCHAR(17) NULL COMMENT 'Dirección MAC en formato XX:XX:XX:XX:XX:XX',
    
    -- Hostname del dispositivo conflictivo
    hostname_conflictivo VARCHAR(255) NULL COMMENT 'Nombre del host en conflicto',
    
    -- Fecha y hora exacta de detección del conflicto
    fecha_detectado DATETIME NOT NULL COMMENT 'Timestamp de detección del conflicto',
    
    -- Descripción detallada del tipo de conflicto
    descripcion TEXT NOT NULL COMMENT 'Explicación del conflicto detectado',
    
    -- Estado actual del conflicto
    estado ENUM('activo', 'resuelto') DEFAULT 'activo' COMMENT 'Estado del conflicto',
    
    -- Restricción: al menos IP o MAC debe tener valor
    CONSTRAINT chk_ip_or_mac CHECK (ip IS NOT NULL OR mac IS NOT NULL),
    
    -- Restricción: validación de longitud de IP
    CONSTRAINT chk_ip_length CHECK (ip IS NULL OR (CHAR_LENGTH(ip) >= 7 AND CHAR_LENGTH(ip) <= 45)),
    
    -- Restricción: validación de longitud de MAC
    CONSTRAINT chk_mac_length CHECK (mac IS NULL OR CHAR_LENGTH(mac) = 17)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro histórico de conflictos de red detectados';

-- ==============================================================================
-- Índices para optimización de consultas
-- ==============================================================================

-- Índice para búsqueda rápida por dirección IP
CREATE INDEX idx_ip ON conflictos(ip);

-- Índice para búsqueda rápida por dirección MAC
CREATE INDEX idx_mac ON conflictos(mac);

-- Índice combinado para consultas que filtran por IP y MAC simultáneamente
CREATE INDEX idx_ip_mac ON conflictos(ip, mac);

-- Índice para búsqueda por estado del conflicto
CREATE INDEX idx_estado ON conflictos(estado);

-- Índice para búsqueda por fecha de detección (útil para reportes históricos)
CREATE INDEX idx_fecha_detectado ON conflictos(fecha_detectado);
