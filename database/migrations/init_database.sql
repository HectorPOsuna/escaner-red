-- ==============================================================================
-- Migración Inicial #7: Esquema Completo del Modelo
-- Fecha: 2025-12-02
-- Descripción: Generación de tablas base, índices y datos iniciales.
-- ==============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- Eliminar tablas en orden inverso para evitar errores de FK
DROP TABLE IF EXISTS logs;
DROP TABLE IF EXISTS protocolos_usados;
DROP TABLE IF EXISTS conflictos;
DROP TABLE IF EXISTS equipos;
DROP TABLE IF EXISTS sistemas_operativos;
DROP TABLE IF EXISTS protocolos;
DROP TABLE IF EXISTS fabricantes;

-- ==============================================================================
-- 1. Tabla: fabricantes
-- ==============================================================================
CREATE TABLE IF NOT EXISTS fabricantes (
    id_fabricante INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del fabricante',
    nombre VARCHAR(100) NOT NULL COMMENT 'Nombre completo del fabricante',
    oui_mac VARCHAR(20) NOT NULL UNIQUE COMMENT 'OUI de la MAC (ej: 00:00:0C o 00000C)',
    CONSTRAINT uk_oui_mac UNIQUE (oui_mac),
    INDEX idx_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catálogo de fabricantes identificados por OUI de direcciones MAC';

-- ==============================================================================
-- 2. Tabla: protocolos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS protocolos (
    id_protocolo INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del protocolo',
    numero INT NOT NULL COMMENT 'Número de puerto estándar (ej. 80, 443)',
    nombre VARCHAR(50) NOT NULL COMMENT 'Nombre del protocolo (ej. HTTP, SSH)',
    categoria ENUM('seguro', 'inseguro', 'precaucion', 'esencial', 'base_de_datos', 'correo', 'otro') 
        DEFAULT 'otro' NOT NULL COMMENT 'Clasificación de seguridad o tipo de servicio',
    descripcion TEXT NULL COMMENT 'Descripción detallada del protocolo',
    CONSTRAINT uk_protocolo_numero UNIQUE (numero),
    INDEX idx_protocolos_numero (numero),
    INDEX idx_protocolos_nombre (nombre),
    INDEX idx_protocolos_categoria (categoria)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catálogo de protocolos y puertos estándar';

-- ==============================================================================
-- 3. Tabla: sistemas_operativos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS sistemas_operativos (
    id_so INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del sistema operativo',
    nombre VARCHAR(100) NOT NULL UNIQUE COMMENT 'Nombre del Sistema Operativo',
    CONSTRAINT uk_so_nombre UNIQUE (nombre),
    INDEX idx_so_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Catálogo de sistemas operativos detectados';

-- ==============================================================================
-- 4. Tabla: equipos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS equipos (
    id_equipo INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del dispositivo',
    hostname VARCHAR(255) NULL COMMENT 'Nombre de host resuelto o NetBIOS',
    ip VARCHAR(45) NOT NULL COMMENT 'Dirección IP del dispositivo',
    mac VARCHAR(17) NULL COMMENT 'Dirección MAC en formato XX:XX:XX:XX:XX:XX',
    fabricante_id INT NOT NULL COMMENT 'ID del fabricante (FK) - Obligatorio',
    id_so INT NULL COMMENT 'ID del Sistema Operativo (FK)',
    ultima_deteccion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Timestamp de la última vez que fue visto',
    CONSTRAINT fk_equipos_fabricante FOREIGN KEY (fabricante_id) REFERENCES fabricantes(id_fabricante) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_equipos_so FOREIGN KEY (id_so) REFERENCES sistemas_operativos(id_so) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT uk_equipos_ip UNIQUE (ip),
    CONSTRAINT uk_equipos_mac UNIQUE (mac),
    CONSTRAINT chk_equipos_ip_length CHECK (CHAR_LENGTH(ip) >= 7 AND CHAR_LENGTH(ip) <= 45),
    CONSTRAINT chk_equipos_mac_length CHECK (mac IS NULL OR CHAR_LENGTH(mac) = 17),
    INDEX idx_equipos_ip (ip),
    INDEX idx_equipos_mac (mac),
    INDEX idx_equipos_fabricante (fabricante_id),
    INDEX idx_equipos_so (id_so),
    INDEX idx_equipos_hostname (hostname)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Inventario de equipos detectados en la red';

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
    CONSTRAINT chk_mac_length CHECK (mac IS NULL OR CHAR_LENGTH(mac) = 17),
    INDEX idx_ip (ip),
    INDEX idx_mac (mac),
    INDEX idx_ip_mac (ip, mac),
    INDEX idx_estado (estado),
    INDEX idx_fecha_detectado (fecha_detectado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro histórico de conflictos de red detectados';

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
    CONSTRAINT fk_uso_protocolo FOREIGN KEY (id_protocolo) REFERENCES protocolos(id_protocolo) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_uso_equipo (id_equipo),
    INDEX idx_uso_protocolo (id_protocolo),
    INDEX idx_uso_equipo_protocolo (id_equipo, id_protocolo),
    INDEX idx_uso_fecha (fecha_hora),
    INDEX idx_uso_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Registro histórico de protocolos detectados en equipos';

-- ==============================================================================
-- 6. Tabla: logs
-- ==============================================================================
CREATE TABLE IF NOT EXISTS logs (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_equipo INT NULL,
    mensaje TEXT NOT NULL,
    nivel ENUM('info', 'warning', 'error') DEFAULT 'info',
    fecha_hora DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_equipo) REFERENCES equipos(id_equipo) ON DELETE SET NULL,
    INDEX idx_logs_equipo (id_equipo),
    INDEX idx_logs_nivel (nivel),
    INDEX idx_logs_fecha (fecha_hora)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- 7. Datos Iniciales (Seed Data)
-- ==============================================================================
-- Fabricante por defecto para equipos desconocidos
INSERT IGNORE INTO fabricantes (id_fabricante, nombre, oui_mac) VALUES (1, 'Desconocido', '000000');

INSERT IGNORE INTO protocolos (numero, nombre, categoria, descripcion) VALUES
(20, 'FTP-DATA', 'inseguro', 'File Transfer Protocol (Data)'),
(21, 'FTP', 'inseguro', 'File Transfer Protocol (Control)'),
(22, 'SSH', 'seguro', 'Secure Shell'),
(23, 'Telnet', 'inseguro', 'Telnet (Unencrypted text communications)'),
(25, 'SMTP', 'correo', 'Simple Mail Transfer Protocol'),
(53, 'DNS', 'esencial', 'Domain Name System'),
(80, 'HTTP', 'inseguro', 'Hypertext Transfer Protocol'),
(443, 'HTTPS', 'seguro', 'Hypertext Transfer Protocol Secure'),
(445, 'SMB', 'precaucion', 'Server Message Block'),
(3306, 'MySQL', 'base_de_datos', 'MySQL Database'),
(3389, 'RDP', 'precaucion', 'Remote Desktop Protocol'),
(5432, 'PostgreSQL', 'base_de_datos', 'PostgreSQL Database');

SET FOREIGN_KEY_CHECKS = 1;
