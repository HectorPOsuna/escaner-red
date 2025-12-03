const { createConnection } = require('../../database/dbConnection');

class DbService {
    constructor() {
        this.pool = null;
    }

    async getConnection() {
        // Reutilizar la lógica de conexión existente
        return await createConnection();
    }

    // --- Fabricantes ---
    async getFabricanteByName(nombre) {
        const conn = await this.getConnection();
        try {
            const [rows] = await conn.execute('SELECT * FROM fabricantes WHERE nombre = ?', [nombre]);
            return rows[0];
        } finally {
            await conn.end();
        }
    }

    async getFabricanteByOui(oui) {
        const conn = await this.getConnection();
        try {
            const [rows] = await conn.execute('SELECT * FROM fabricantes WHERE oui_mac = ?', [oui]);
            return rows[0];
        } finally {
            await conn.end();
        }
    }

    async createFabricante(nombre, oui = '000000') {
        const conn = await this.getConnection();
        try {
            // Generar un OUI dummy si no existe, o usar uno real si lo tenemos
            // Aquí asumimos que el nombre es lo principal si no tenemos OUI
            const [result] = await conn.execute(
                'INSERT INTO fabricantes (nombre, oui_mac) VALUES (?, ?) ON DUPLICATE KEY UPDATE nombre = nombre',
                [nombre, oui]
            );
            return result.insertId || (await this.getFabricanteByName(nombre)).id_fabricante;
        } finally {
            await conn.end();
        }
    }

    // --- Equipos ---
    async getAllEquipos() {
        const conn = await this.getConnection();
        try {
            const query = `
                SELECT 
                    e.id_equipo,
                    e.hostname,
                    e.ip,
                    e.mac,
                    e.sistema_operativo as os,
                    f.nombre as fabricante,
                    e.ultima_deteccion,
                    (
                        SELECT p.nombre 
                        FROM protocolos_usados pu 
                        JOIN protocolos p ON pu.id_protocolo = p.id_protocolo 
                        WHERE pu.id_equipo = e.id_equipo 
                        ORDER BY pu.fecha_hora DESC 
                        LIMIT 1
                    ) as ultimo_protocolo
                FROM equipos e
                LEFT JOIN fabricantes f ON e.fabricante_id = f.id_fabricante
                ORDER BY e.ultima_deteccion DESC
            `;
            const [rows] = await conn.execute(query);
            return rows;
        } finally {
            await conn.end();
        }
    }

    async getEquipoByMac(mac) {
        const conn = await this.getConnection();
        try {
            const [rows] = await conn.execute('SELECT * FROM equipos WHERE mac = ?', [mac]);
            return rows[0];
        } finally {
            await conn.end();
        }
    }

    async getEquipoByIp(ip) {
        const conn = await this.getConnection();
        try {
            const [rows] = await conn.execute('SELECT * FROM equipos WHERE ip = ?', [ip]);
            return rows[0];
        } finally {
            await conn.end();
        }
    }

    async getEquipoByHostname(hostname) {
        const conn = await this.getConnection();
        try {
            const [rows] = await conn.execute('SELECT * FROM equipos WHERE hostname = ?', [hostname]);
            return rows[0];
        } finally {
            await conn.end();
        }
    }

    async upsertEquipo(equipoData) {
        const conn = await this.getConnection();
        try {
            // Intentar buscar por MAC primero
            let existing = null;
            if (equipoData.mac) {
                [existing] = await conn.execute('SELECT * FROM equipos WHERE mac = ?', [equipoData.mac]);
            }
            
            // Si no hay MAC o no se encontró, buscar por IP
            if ((!existing || existing.length === 0) && equipoData.ip) {
                [existing] = await conn.execute('SELECT * FROM equipos WHERE ip = ?', [equipoData.ip]);
            }

            if (existing && existing.length > 0) {
                // Actualizar
                const id = existing[0].id_equipo;
                await conn.execute(
                    'UPDATE equipos SET hostname = ?, ip = ?, sistema_operativo = ?, fabricante_id = ?, ultima_deteccion = NOW() WHERE id_equipo = ?',
                    [equipoData.hostname, equipoData.ip, equipoData.os, equipoData.fabricante_id, id]
                );
                return id;
            } else {
                // Insertar
                const [result] = await conn.execute(
                    'INSERT INTO equipos (hostname, ip, mac, sistema_operativo, fabricante_id, ultima_deteccion) VALUES (?, ?, ?, ?, ?, NOW())',
                    [equipoData.hostname, equipoData.ip, equipoData.mac, equipoData.os, equipoData.fabricante_id]
                );
                return result.insertId;
            }
        } finally {
            await conn.end();
        }
    }

    // --- Conflictos ---
    async registerConflict(conflictData) {
        const conn = await this.getConnection();
        try {
            await conn.execute(
                'INSERT INTO conflictos (ip, mac, hostname_conflictivo, fecha_detectado, descripcion, estado) VALUES (?, ?, ?, NOW(), ?, "activo")',
                [conflictData.ip, conflictData.mac, conflictData.hostname, conflictData.description]
            );
            console.log(`⚠️ Conflicto registrado: ${conflictData.description}`);
        } finally {
            await conn.end();
        }
    }

    // --- Protocolos ---
    async getProtocoloByPort(port) {
        const conn = await this.getConnection();
        try {
            const [rows] = await conn.execute('SELECT * FROM protocolos WHERE numero = ?', [port]);
            return rows[0];
        } finally {
            await conn.end();
        }
    }

    async getAllProtocols() {
        const conn = await this.getConnection();
        try {
            // Limitamos a puertos comunes si son demasiados, o traemos todos.
            // Para el escáner, traeremos todos los que tengan categoría definida o sean < 10000
            const [rows] = await conn.execute('SELECT numero as port, nombre as protocol FROM protocolos ORDER BY numero ASC');
            return rows;
        } finally {
            await conn.end();
        }
    }

    async getProtocolosByCategoria(categoria) {
        const conn = await this.getConnection();
        try {
            const [rows] = await conn.execute(
                'SELECT numero as port, nombre as protocol, descripcion FROM protocolos WHERE categoria = ? ORDER BY numero ASC', 
                [categoria]
            );
            return rows;
        } finally {
            await conn.end();
        }
    }

    async createProtocolo(port, name, category = 'otro') {
        const conn = await this.getConnection();
        try {
            const [result] = await conn.execute(
                'INSERT INTO protocolos (numero, nombre, categoria) VALUES (?, ?, ?)',
                [port, name, category]
            );
            return result.insertId;
        } catch (e) {
            // Si ya existe (duplicate key), devolver el ID existente
            const existing = await this.getProtocoloByPort(port);
            return existing ? existing.id_protocolo : null;
        } finally {
            await conn.end();
        }
    }

    async registerProtocolUse(id_equipo, id_protocolo, port, detected_at) {
        const conn = await this.getConnection();
        try {
            // Verificar si ya existe este uso recientemente (opcional, para no llenar la tabla)
            // Por ahora insertamos siempre un nuevo registro de "foto" del momento
            await conn.execute(
                'INSERT INTO protocolos_usados (id_equipo, id_protocolo, fecha_hora, estado, puerto_detectado) VALUES (?, ?, ?, "activo", ?)',
                [id_equipo, id_protocolo, detected_at || new Date(), port]
            );
        } finally {
            await conn.end();
        }
    }
}

module.exports = new DbService();
