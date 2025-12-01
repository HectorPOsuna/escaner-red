-- ==============================================================================
-- Tabla: equipos
-- Descripción: Almacena el inventario de dispositivos detectados en la red
--              Vincula cada equipo con su fabricante y registra su configuración
-- Motor: InnoDB para soporte de transacciones y claves foráneas
-- Charset: utf8mb4 para compatibilidad completa con Unicode
-- ==============================================================================

CREATE TABLE IF NOT EXISTS equipos (
    -- Identificador único del equipo
    id_equipo INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del dispositivo',
    
    -- Nombre de host del dispositivo
    hostname VARCHAR(255) NULL COMMENT 'Nombre de host resuelto o NetBIOS',
    
    -- Dirección IP actual (IPv4 o IPv6)
    ip VARCHAR(45) NOT NULL COMMENT 'Dirección IP del dispositivo',
    
    -- Dirección MAC física
    mac VARCHAR(17) NULL COMMENT 'Dirección MAC en formato XX:XX:XX:XX:XX:XX',
    
    -- Referencia al fabricante (Foreign Key)
    fabricante_id INT NULL COMMENT 'ID del fabricante (FK)',
    
    -- Sistema Operativo detectado
    sistema_operativo VARCHAR(100) NULL COMMENT 'Sistema Operativo o tipo de dispositivo detectado',
    
    -- Fecha de última detección
    ultima_deteccion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Timestamp de la última vez que fue visto',
    
    -- Restricción de clave foránea hacia la tabla fabricantes
    CONSTRAINT fk_equipos_fabricante
        FOREIGN KEY (fabricante_id)
        REFERENCES fabricantes(id_fabricante)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
        
    -- Índice único para evitar duplicados lógicos (opcional, depende de la lógica de negocio, 
    -- aquí asumimos que MAC debe ser única si existe, o IP si MAC es nula)
    -- CONSTRAINT uk_mac UNIQUE (mac) -- Comentado para permitir flexibilidad si se requiere
    
    -- Validación básica de formato
    CONSTRAINT chk_equipos_ip_length CHECK (CHAR_LENGTH(ip) >= 7 AND CHAR_LENGTH(ip) <= 45),
    CONSTRAINT chk_equipos_mac_length CHECK (mac IS NULL OR CHAR_LENGTH(mac) = 17)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Inventario de equipos detectados en la red';

-- ==============================================================================
-- Índices para optimización de consultas
-- ==============================================================================

-- Índice para búsqueda rápida por IP
CREATE INDEX idx_equipos_ip ON equipos(ip);

-- Índice para búsqueda rápida por MAC
CREATE INDEX idx_equipos_mac ON equipos(mac);

-- Índice para búsqueda por fabricante
CREATE INDEX idx_equipos_fabricante ON equipos(fabricante_id);

-- Índice para búsqueda por sistema operativo
CREATE INDEX idx_equipos_os ON equipos(sistema_operativo);

-- Índice para búsquedas por hostname
CREATE INDEX idx_equipos_hostname ON equipos(hostname);
