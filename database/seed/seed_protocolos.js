const fs = require('fs');
const path = require('path');
const { createConnection } = require('../dbConnection');

const IANA_CSV_URL = 'https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.csv';

async function seedProtocolos() {
    console.log('🚀 Iniciando sembrado de protocolos desde IANA...');

    let conn;
    try {
        // 1. Descargar CSV
        console.log('📥 Descargando lista de protocolos...');
        const response = await fetch(IANA_CSV_URL);
        if (!response.ok) throw new Error(`Error descargando CSV: ${response.statusText}`);
        const csvText = await response.text();

        // 2. Parsear CSV (Implementación simple para evitar dependencias extra)
        console.log('⚙️  Procesando datos...');
        const lines = csvText.split('\n');
        const protocolsToInsert = [];
        
        // Ignorar encabezado
        for (let i = 1; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;

            // Parseo básico de CSV respetando comillas
            // Service Name, Port Number, Transport Protocol, Description, ...
            const parts = line.match(/(".*?"|[^",\s]+)(?=\s*,|\s*$)/g);
            
            if (!parts || parts.length < 3) continue;

            const serviceName = parts[0]?.replace(/"/g, '').trim();
            const portNumber = parseInt(parts[1]?.replace(/"/g, '').trim());
            const transportProtocol = parts[2]?.replace(/"/g, '').trim().toLowerCase();
            const description = parts[3]?.replace(/"/g, '').trim() || serviceName;

            // Validar datos mínimos
            if (!serviceName || isNaN(portNumber) || !transportProtocol) continue;

            // Solo nos interesan TCP y UDP
            if (transportProtocol !== 'tcp' && transportProtocol !== 'udp') continue;

            // Determinar categoría
            let categoria = 'otro';
            const lowerDesc = description.toLowerCase();
            const lowerName = serviceName.toLowerCase();

            if (['ssh', 'https', 'sftp', 'ftps', 'tls', 'ssl'].some(k => lowerName.includes(k))) categoria = 'seguro';
            else if (['telnet', 'ftp', 'http', 'tftp'].some(k => lowerName === k)) categoria = 'inseguro';
            else if (['dns', 'dhcp', 'ntp'].some(k => lowerName.includes(k))) categoria = 'esencial';
            else if (['sql', 'mysql', 'postgresql', 'oracle', 'mongo', 'redis'].some(k => lowerName.includes(k))) categoria = 'base_de_datos';
            else if (['smtp', 'imap', 'pop3', 'mail'].some(k => lowerName.includes(k))) categoria = 'correo';

            protocolsToInsert.push([portNumber, serviceName, categoria, description.substring(0, 65535)]);
        }

        console.log(`📊 Se encontraron ${protocolsToInsert.length} protocolos válidos.`);

        // 3. Insertar en Base de Datos (Batch)
        conn = await createConnection();
        const batchSize = 1000;
        let insertedCount = 0;

        for (let i = 0; i < protocolsToInsert.length; i += batchSize) {
            const batch = protocolsToInsert.slice(i, i + batchSize);
            
            // Usamos INSERT IGNORE para no fallar si el puerto ya existe (priorizamos el primero que encontramos o el seed manual)
            // Nota: La tabla tiene UNIQUE(numero), así que solo entrará el primer protocolo definido para ese puerto.
            // IANA suele tener TCP y UDP para el mismo puerto. Aquí ganará el primero que procesemos.
            const query = `
                INSERT IGNORE INTO protocolos (numero, nombre, categoria, descripcion) 
                VALUES ?
            `;
            
            const [result] = await conn.query(query, [batch]);
            insertedCount += result.affectedRows;
            
            process.stdout.write(`\r💾 Insertados: ${insertedCount} / ${protocolsToInsert.length}`);
        }

        console.log(`\n✅ Sembrado completado. ${insertedCount} nuevos protocolos agregados.`);

    } catch (error) {
        console.error('\n❌ Error en el sembrado:', error);
    } finally {
        if (conn) conn.end();
    }
}

// Ejecutar si se llama directamente
if (require.main === module) {
    seedProtocolos();
}

module.exports = { seedProtocolos };
