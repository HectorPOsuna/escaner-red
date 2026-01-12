-- ==============================================================================
-- Migración #X: Historial de Puertos (Sesiones)
-- Fecha: 2026-01-10
-- Descripción: Tabla para rastrear sesiones de uso de puertos (Inicio/Fin)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS historial_puertos (
    id_historial INT AUTO_INCREMENT PRIMARY KEY,
    id_equipo INT NOT NULL,
    id_protocolo INT NOT NULL,
    puerto INT NOT NULL COMMENT 'Puerto detectado (puede diferir del estándar del protocolo)',
    fecha_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin DATETIME NULL COMMENT 'NULL indica que la sesión sigue activa',
    
    FOREIGN KEY (id_equipo) REFERENCES equipos(id_equipo) ON DELETE CASCADE,
    FOREIGN KEY (id_protocolo) REFERENCES protocolos(id_protocolo) ON DELETE CASCADE,
    
    INDEX idx_hist_equipo (id_equipo),
    INDEX idx_hist_activo (id_equipo, fecha_fin) -- Para busquedas rápidas de sesiones activas
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
