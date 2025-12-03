const dbService = require('../services/dbService');

async function processScanResults(req, res) {
    const { scan_timestamp, subnet, hosts } = req.body;

    if (!hosts || !Array.isArray(hosts)) {
        return res.status(400).json({ error: 'Invalid payload format' });
    }

    console.log(`📥 Recibidos resultados de escaneo: ${hosts.length} hosts. Subnet: ${subnet}`);
    
    const results = {
        processed: 0,
        conflicts: 0,
        errors: 0
    };

    for (const host of hosts) {
        try {
            // 1. Validación de Conflictos
            let conflictDetected = false;

            // A) Conflicto de IP: La IP ya existe pero con otro Hostname/MAC
            if (host.ip) {
                const existingIp = await dbService.getEquipoByIp(host.ip);
                if (existingIp) {
                    // Si existe la IP, verificamos si es el mismo equipo (mismo MAC o mismo Hostname)
                    // Si el MAC es diferente (y ambos tienen MAC), es un conflicto seguro de IP duplicada
                    if (host.mac && existingIp.mac && host.mac !== existingIp.mac) {
                        await dbService.registerConflict({
                            ip: host.ip,
                            mac: host.mac,
                            hostname: host.hostname,
                            description: `Conflicto de IP: La IP ${host.ip} está asignada a ${existingIp.hostname} (${existingIp.mac}) pero fue detectada en ${host.hostname} (${host.mac})`
                        });
                        conflictDetected = true;
                        results.conflicts++;
                    }
                    // Si el hostname es diferente (y no es un simple cambio de nombre legítimo validado por MAC), podría ser conflicto
                    else if (host.hostname && existingIp.hostname && host.hostname !== existingIp.hostname) {
                         // Si la MAC coincide, es un cambio de nombre (no conflicto). Si no coincide (o no hay MAC), es sospechoso.
                         if (!host.mac || !existingIp.mac || host.mac !== existingIp.mac) {
                            await dbService.registerConflict({
                                ip: host.ip,
                                mac: host.mac,
                                hostname: host.hostname,
                                description: `Conflicto de Hostname en IP: La IP ${host.ip} cambió de ${existingIp.hostname} a ${host.hostname} sin validación de MAC.`
                            });
                            conflictDetected = true;
                            results.conflicts++;
                         }
                    }
                }
            }

            // B) Conflicto de MAC: La MAC ya existe con otro Hostname (Requerimiento estricto del usuario)
            if (host.mac) {
                const existingMac = await dbService.getEquipoByMac(host.mac);
                if (existingMac) {
                    if (host.hostname && existingMac.hostname && host.hostname !== existingMac.hostname) {
                        await dbService.registerConflict({
                            ip: host.ip,
                            mac: host.mac,
                            hostname: host.hostname,
                            description: `Conflicto de MAC: El dispositivo ${host.mac} cambió de nombre de ${existingMac.hostname} a ${host.hostname}`
                        });
                        // Nota: El usuario pidió registrar conflicto, pero esto también podría ser un rename legítimo.
                        // Lo registramos como conflicto según requerimiento, pero permitimos la actualización del equipo abajo.
                        conflictDetected = true;
                        results.conflicts++;
                    }
                }
            }

            // 2. Persistencia de Datos (Upsert)
            // Aunque haya conflicto, actualizamos el inventario con lo último visto (o podríamos decidir no hacerlo)
            // Asumiremos que "lo último visto" es la verdad actual, pero el conflicto queda registrado.
            
            // a) Fabricante
            let fabricanteId = null;
            let oui = null;

            if (host.mac) {
                // Normalizar OUI: XX:XX:XX... -> XXXXXX (primeros 6 chars)
                oui = host.mac.replace(/[:-]/g, '').substring(0, 6).toUpperCase();
                
                // 1. Intentar buscar por OUI en la base de datos (prioridad)
                const fabricanteDb = await dbService.getFabricanteByOui(oui);
                
                if (fabricanteDb) {
                    fabricanteId = fabricanteDb.id_fabricante;
                }
            }

            // 2. Si no se encontró por OUI, pero el agente envió un nombre válido, crearlo/buscarlo por nombre
            if (!fabricanteId && host.manufacturer && host.manufacturer !== 'Desconocido') {
                fabricanteId = await dbService.createFabricante(host.manufacturer, oui || '000000');
            }

            // b) Equipo
            const equipoId = await dbService.upsertEquipo({
                hostname: host.hostname,
                ip: host.ip,
                mac: host.mac,
                os: host.os,
                fabricante_id: fabricanteId
            });

            // c) Protocolos
            if (host.open_ports && Array.isArray(host.open_ports)) {
                for (const portInfo of host.open_ports) {
                    let protocoloId = null;

                    // 1. Intentar buscar el protocolo en nuestro catálogo (prioridad a IANA/Seed)
                    const existingProtocol = await dbService.getProtocoloByPort(portInfo.port);
                    
                    if (existingProtocol) {
                        protocoloId = existingProtocol.id_protocolo;
                    } else {
                        // 2. Si no existe, lo creamos con la información del agente (o Unknown)
                        // Esto permite aprender nuevos puertos no catalogados
                        protocoloId = await dbService.createProtocolo(
                            portInfo.port, 
                            portInfo.protocol || 'Unknown', 
                            'otro'
                        );
                    }

                    // Registrar uso
                    if (protocoloId) {
                        await dbService.registerProtocolUse(
                            equipoId, 
                            protocoloId, 
                            portInfo.port, 
                            new Date() // Usar hora actual del servidor
                        );
                    }
                }
            }

            results.processed++;

        } catch (error) {
            console.error(`❌ Error procesando host ${host.ip}:`, error.message);
            results.errors++;
        }
    }

    res.json({
        message: 'Scan results processed',
        summary: results
    });
}

async function getProtocols(req, res) {
    try {
        const protocols = await dbService.getAllProtocols();
        res.json(protocols);
    } catch (error) {
        console.error('❌ Error obteniendo protocolos:', error.message);
        res.status(500).json({ error: 'Error retrieving protocols' });
    }
}

async function getEquipos(req, res) {
    try {
        const equipos = await dbService.getAllEquipos();
        res.json(equipos);
    } catch (error) {
        console.error('❌ Error obteniendo equipos:', error.message);
        res.status(500).json({ error: 'Error retrieving equipment list' });
    }
}

module.exports = { processScanResults, getProtocols, getEquipos };
