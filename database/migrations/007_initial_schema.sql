-- ==============================================================================
-- Migración Inicial #7: Esquema Completo del Modelo
-- Fecha: 2025-12-02
-- Descripción: Generación de tablas base, índices y datos iniciales.
-- ==============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ==============================================================================
-- 1. Tabla: fabricantes
-- ==============================================================================
CREATE TABLE IF NOT EXISTS fabricantes (
    id_fabricante INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del fabricante',
    nombre VARCHAR(100) NOT NULL COMMENT 'Nombre completo del fabricante',
    oui_mac VARCHAR(20) NOT NULL UNIQUE COMMENT 'OUI de la MAC (ej: 00:00:0C o 00000C)',
    CONSTRAINT uk_oui_mac UNIQUE (oui_mac)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catálogo de fabricantes identificados por OUI de direcciones MAC';

CREATE INDEX idx_nombre ON fabricantes(nombre);

-- ==============================================================================
-- 2. Tabla: protocolos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS protocolos (
    id_protocolo INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del protocolo',
    numero INT NOT NULL COMMENT 'Número de puerto estándar (ej. 80, 443)',
    nombre VARCHAR(50) NOT NULL COMMENT 'Nombre del protocolo (ej. HTTP, SSH)',
    categoria ENUM('seguro', 'inseguro', 'esencial', 'base_de_datos', 'correo', 'otro') 
        DEFAULT 'otro' NOT NULL COMMENT 'Clasificación de seguridad o tipo de servicio',
    descripcion TEXT NULL COMMENT 'Descripción detallada del protocolo',
    CONSTRAINT uk_protocolo_numero UNIQUE (numero)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catálogo de protocolos y puertos estándar';

CREATE INDEX idx_protocolos_numero ON protocolos(numero);
CREATE INDEX idx_protocolos_nombre ON protocolos(nombre);
CREATE INDEX idx_protocolos_categoria ON protocolos(categoria);

-- ==============================================================================
-- 3. Tabla: equipos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS equipos (
    id_equipo INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del dispositivo',
    hostname VARCHAR(255) NULL COMMENT 'Nombre de host resuelto o NetBIOS',
    ip VARCHAR(45) NOT NULL COMMENT 'Dirección IP del dispositivo',
    mac VARCHAR(17) NULL COMMENT 'Dirección MAC en formato XX:XX:XX:XX:XX:XX',
    fabricante_id INT NULL COMMENT 'ID del fabricante (FK)',
    sistema_operativo VARCHAR(100) NULL COMMENT 'Sistema Operativo o tipo de dispositivo detectado',
    ultima_deteccion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Timestamp de la última vez que fue visto',
    CONSTRAINT fk_equipos_fabricante FOREIGN KEY (fabricante_id) REFERENCES fabricantes(id_fabricante) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_equipos_ip_length CHECK (CHAR_LENGTH(ip) >= 7 AND CHAR_LENGTH(ip) <= 45),
    CONSTRAINT chk_equipos_mac_length CHECK (mac IS NULL OR CHAR_LENGTH(mac) = 17)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Inventario de equipos detectados en la red';

CREATE INDEX idx_equipos_ip ON equipos(ip);
CREATE INDEX idx_equipos_mac ON equipos(mac);
CREATE INDEX idx_equipos_fabricante ON equipos(fabricante_id);
CREATE INDEX idx_equipos_os ON equipos(sistema_operativo);
CREATE INDEX idx_equipos_hostname ON equipos(hostname);

-- ==============================================================================
-- 4. Tabla: conflictos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS conflictos (
    id_conflicto INT AUTO_INCREMENT PRIMARY KEY,
    ip VARCHAR(45) NULL COMMENT 'Dirección IP del conflicto (IPv4 o IPv6)',
    mac VARCHAR(17) NULL COMMENT 'Dirección MAC en formato XX:XX:XX:XX:XX:XX',
    hostname_conflictivo VARCHAR(255) NULL COMMENT 'Nombre del host en conflicto',
    fecha_detectado DATETIME NOT NULL COMMENT 'Timestamp de detección del conflicto',
    descripcion TEXT NOT NULL COMMENT 'Explicación del conflicto detectado',
    estado ENUM('activo', 'resuelto') DEFAULT 'activo' COMMENT 'Estado del conflicto',
    CONSTRAINT chk_ip_or_mac CHECK (ip IS NOT NULL OR mac IS NOT NULL),
    CONSTRAINT chk_ip_length CHECK (ip IS NULL OR (CHAR_LENGTH(ip) >= 7 AND CHAR_LENGTH(ip) <= 45)),
    CONSTRAINT chk_mac_length CHECK (mac IS NULL OR CHAR_LENGTH(mac) = 17)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro histórico de conflictos de red detectados';

CREATE INDEX idx_ip ON conflictos(ip);
CREATE INDEX idx_mac ON conflictos(mac);
CREATE INDEX idx_ip_mac ON conflictos(ip, mac);
CREATE INDEX idx_estado ON conflictos(estado);
CREATE INDEX idx_fecha_detectado ON conflictos(fecha_detectado);

-- ==============================================================================
-- 5. Tabla: protocolos_usados
-- ==============================================================================
CREATE TABLE IF NOT EXISTS protocolos_usados (
    id_uso INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del registro de uso',
    id_equipo INT NOT NULL COMMENT 'ID del equipo (FK)',
    id_protocolo INT NOT NULL COMMENT 'ID del protocolo (FK)',
    fecha_hora DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'Momento exacto de la detección',
    estado ENUM('activo', 'inactivo') DEFAULT 'activo' NOT NULL COMMENT 'Estado del servicio detectado',
    puerto_detectado INT NOT NULL COMMENT 'Puerto real donde se detectó el servicio',
    CONSTRAINT fk_uso_equipo FOREIGN KEY (id_equipo) REFERENCES equipos(id_equipo) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_uso_protocolo FOREIGN KEY (id_protocolo) REFERENCES protocolos(id_protocolo) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro histórico de protocolos detectados en equipos';

CREATE INDEX idx_uso_equipo ON protocolos_usados(id_equipo);
CREATE INDEX idx_uso_protocolo ON protocolos_usados(id_protocolo);
CREATE INDEX idx_uso_equipo_protocolo ON protocolos_usados(id_equipo, id_protocolo);
CREATE INDEX idx_uso_fecha ON protocolos_usados(fecha_hora);
CREATE INDEX idx_uso_estado ON protocolos_usados(estado);

-- ==============================================================================
-- 6. Datos Iniciales (Seed Data)
-- ==============================================================================
INSERT IGNORE INTO protocolos (numero, nombre, categoria, descripcion) VALUES
(20, 'FTP-DATA', 'inseguro', 'File Transfer Protocol (Data)'),
(21, 'FTP', 'inseguro', 'File Transfer Protocol (Control)'),
(22, 'SSH', 'seguro', 'Secure Shell'),
(23, 'Telnet', 'inseguro', 'Telnet (Unencrypted text communications)'),
(25, 'SMTP', 'correo', 'Simple Mail Transfer Protocol'),
(53, 'DNS', 'esencial', 'Domain Name System'),
(80, 'HTTP', 'inseguro', 'Hypertext Transfer Protocol'),
(443, 'HTTPS', 'seguro', 'Hypertext Transfer Protocol Secure'),
(3306, 'MySQL', 'base_de_datos', 'MySQL Database'),
(3389, 'RDP', 'esencial', 'Remote Desktop Protocol'),
(5432, 'PostgreSQL', 'base_de_datos', 'PostgreSQL Database');

SET FOREIGN_KEY_CHECKS = 1;
