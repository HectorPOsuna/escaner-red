-- ==============================================================================
-- Tabla: protocolos_usados (Tabla Pivot)
-- Descripción: Relaciona equipos con los protocolos detectados en ellos.
--              Registra qué servicios están activos en cada dispositivo y cuándo.
-- Motor: InnoDB para soporte de transacciones y claves foráneas
-- Charset: utf8mb4 para compatibilidad completa con Unicode
-- ==============================================================================

CREATE TABLE IF NOT EXISTS protocolos_usados (
    -- Identificador único del registro de uso
    id_uso INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del registro de uso',
    
    -- Referencia al equipo (Foreign Key)
    id_equipo INT NOT NULL COMMENT 'ID del equipo (FK)',
    
    -- Referencia al protocolo (Foreign Key)
    id_protocolo INT NOT NULL COMMENT 'ID del protocolo (FK)',
    
    -- Fecha y hora de la detección
    fecha_hora DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Momento exacto de la detección',
    
    -- Estado del servicio en ese momento
    estado ENUM('activo', 'inactivo') DEFAULT 'activo' NOT NULL COMMENT 'Estado del servicio detectado',
    
    -- Puerto específico detectado (puede diferir del estándar del protocolo)
    puerto_detectado INT NOT NULL COMMENT 'Puerto real donde se detectó el servicio',
    
    -- Restricción de clave foránea hacia equipos
    CONSTRAINT fk_uso_equipo
        FOREIGN KEY (id_equipo)
        REFERENCES equipos(id_equipo)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
        
    -- Restricción de clave foránea hacia protocolos
    CONSTRAINT fk_uso_protocolo
        FOREIGN KEY (id_protocolo)
        REFERENCES protocolos(id_protocolo)
        ON DELETE CASCADE
        ON UPDATE CASCADE

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro histórico de protocolos detectados en equipos';

-- ==============================================================================
-- Índices para optimización de consultas
-- ==============================================================================

-- Índice para buscar todos los protocolos de un equipo
CREATE INDEX idx_uso_equipo ON protocolos_usados(id_equipo);

-- Índice para buscar todos los equipos que usan un protocolo
CREATE INDEX idx_uso_protocolo ON protocolos_usados(id_protocolo);

-- Índice compuesto para búsquedas rápidas de un protocolo específico en un equipo
CREATE INDEX idx_uso_equipo_protocolo ON protocolos_usados(id_equipo, id_protocolo);

-- Índice para filtrar por fecha (útil para reportes históricos)
CREATE INDEX idx_uso_fecha ON protocolos_usados(fecha_hora);

-- Índice para filtrar por estado
CREATE INDEX idx_uso_estado ON protocolos_usados(estado);
