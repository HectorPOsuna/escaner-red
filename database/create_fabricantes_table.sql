-- ==============================================================================
-- Tabla: fabricantes
-- Descripción: Almacena información de fabricantes de dispositivos de red
--              identificados por su OUI (Organizationally Unique Identifier)
-- Motor: InnoDB para soporte de transacciones y claves foráneas
-- Charset: utf8mb4 para compatibilidad completa con Unicode
-- ==============================================================================

CREATE TABLE IF NOT EXISTS fabricantes (
    -- Identificador único del fabricante
    id_fabricante INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del fabricante',
    
    -- Nombre del fabricante
    nombre VARCHAR(100) NOT NULL COMMENT 'Nombre completo del fabricante',
    
    -- OUI (primeros 3 octetos de la dirección MAC)
    oui_mac VARCHAR(20) NOT NULL UNIQUE COMMENT 'OUI de la MAC (ej: 00:00:0C o 00000C)',
    
    -- Índice único para garantizar que no se repita el OUI
    CONSTRAINT uk_oui_mac UNIQUE (oui_mac)
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catálogo de fabricantes identificados por OUI de direcciones MAC';

-- ==============================================================================
-- Índices adicionales para optimización de consultas
-- ==============================================================================

-- Índice para búsqueda rápida por nombre de fabricante
CREATE INDEX idx_nombre ON fabricantes(nombre);
