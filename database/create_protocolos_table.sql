-- ==============================================================================
-- Tabla: protocolos
-- Descripción: Catálogo de protocolos de red y sus puertos estándar asociados
--              Permite clasificar los servicios detectados por seguridad e importancia
-- Motor: InnoDB para soporte de transacciones
-- Charset: utf8mb4 para compatibilidad completa con Unicode
-- ==============================================================================

CREATE TABLE IF NOT EXISTS protocolos (
    -- Identificador único del protocolo
    id_protocolo INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del protocolo',
    
    -- Número de puerto estándar asociado (ej. 80, 443, 22)
    numero INT NOT NULL COMMENT 'Número de puerto estándar (ej. 80, 443)',
    
    -- Nombre del protocolo o servicio (ej. HTTP, HTTPS, SSH)
    nombre VARCHAR(50) NOT NULL COMMENT 'Nombre del protocolo (ej. HTTP, SSH)',
    
    -- Categoría de seguridad/importancia
    categoria ENUM('seguro', 'inseguro', 'esencial', 'base_de_datos', 'correo', 'otro') 
        DEFAULT 'otro' 
        NOT NULL 
        COMMENT 'Clasificación de seguridad o tipo de servicio',
    
    -- Descripción opcional del protocolo
    descripcion TEXT NULL COMMENT 'Descripción detallada del protocolo',
    
    -- Restricción para evitar duplicados de puerto (asumiendo un protocolo principal por puerto para este catálogo)
    CONSTRAINT uk_protocolo_numero UNIQUE (numero)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catálogo de protocolos y puertos estándar';

-- ==============================================================================
-- Índices para optimización de consultas
-- ==============================================================================

-- Índice para búsqueda rápida por número de puerto
CREATE INDEX idx_protocolos_numero ON protocolos(numero);

-- Índice para búsqueda por nombre
CREATE INDEX idx_protocolos_nombre ON protocolos(nombre);

-- Índice para filtrar por categoría
CREATE INDEX idx_protocolos_categoria ON protocolos(categoria);

-- ==============================================================================
-- Datos semilla (Seed Data) - Opcional, para poblar la tabla inicialmente
-- ==============================================================================
-- INSERT IGNORE INTO protocolos (numero, nombre, categoria, descripcion) VALUES
-- (20, 'FTP-DATA', 'inseguro', 'File Transfer Protocol (Data)'),
-- (21, 'FTP', 'inseguro', 'File Transfer Protocol (Control)'),
-- (22, 'SSH', 'seguro', 'Secure Shell'),
-- (23, 'Telnet', 'inseguro', 'Telnet (Unencrypted text communications)'),
-- (25, 'SMTP', 'correo', 'Simple Mail Transfer Protocol'),
-- (53, 'DNS', 'esencial', 'Domain Name System'),
-- (80, 'HTTP', 'inseguro', 'Hypertext Transfer Protocol'),
-- (443, 'HTTPS', 'seguro', 'Hypertext Transfer Protocol Secure'),
-- (3306, 'MySQL', 'base_de_datos', 'MySQL Database'),
-- (3389, 'RDP', 'esencial', 'Remote Desktop Protocol'),
-- (5432, 'PostgreSQL', 'base_de_datos', 'PostgreSQL Database');
