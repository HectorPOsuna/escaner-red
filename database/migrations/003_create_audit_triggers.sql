-- ==============================================================================
-- Migración: Triggers de Auditoría
-- Descripción: Automatiza la creación de logs cuando cambian los equipos
-- ==============================================================================

USE lisi3309;

DROP TRIGGER IF EXISTS after_insert_equipos;
DROP TRIGGER IF EXISTS after_update_equipos;

DELIMITER $$

-- 1. Trigger para nuevos dispositivos
CREATE TRIGGER after_insert_equipos
AFTER INSERT ON equipos
FOR EACH ROW
BEGIN
    INSERT INTO logs (id_equipo, mensaje, nivel, fecha_hora)
    VALUES (
        NEW.id_equipo, 
        CONCAT('Nuevo dispositivo detectado: ', IFNULL(NEW.hostname, 'Sin Hostname'), ' (', NEW.ip, ')'), 
        'info', 
        NOW()
    );
END$$

-- 2. Trigger para cambios en dispositivos
CREATE TRIGGER after_update_equipos
AFTER UPDATE ON equipos
FOR EACH ROW
BEGIN
    -- Detectar cambio de Hostname
    IF (OLD.hostname IS NULL AND NEW.hostname IS NOT NULL) OR (OLD.hostname != NEW.hostname) THEN
        INSERT INTO logs (id_equipo, mensaje, nivel, fecha_hora)
        VALUES (
            NEW.id_equipo,
            CONCAT('Hostname actualizado: De "', IFNULL(OLD.hostname, 'N/A'), '" a "', NEW.hostname, '"'),
            'info',
            NOW()
        );
    END IF;

    -- Detectar cambio de Sistema Operativo
    IF (OLD.id_so IS NULL AND NEW.id_so IS NOT NULL) OR (OLD.id_so != NEW.id_so) THEN
        INSERT INTO logs (id_equipo, mensaje, nivel, fecha_hora)
        VALUES (
            NEW.id_equipo,
            'Sistema Operativo actualizado/detectado',
            'info',
            NOW()
        );
    END IF;
    
    -- Detectar cambio de Fabricante (si cambia de desconocido a algo conocido)
    IF OLD.fabricante_id = 1 AND NEW.fabricante_id != 1 THEN
         INSERT INTO logs (id_equipo, mensaje, nivel, fecha_hora)
        VALUES (
            NEW.id_equipo,
            'Fabricante identificado',
            'info',
            NOW()
        );
    END IF;
    
END$$

DELIMITER ;
