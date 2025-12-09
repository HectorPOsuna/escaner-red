const fs = require('fs');
const path = require('path');
const axios = require('axios');
const csv = require('csv-parser');
const { createConnection } = require('../lib/db');

const EXEC_BATCH_SIZE = 1000;
const IANA_URL = 'https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.csv';

async function downloadFile(url, dest) {
    console.log('📥 Descargando lista IANA...');
    const response = await axios({
        method: 'get',
        url: url,
        responseType: 'stream'
    });
    
    const writer = fs.createWriteStream(dest);
    response.data.pipe(writer);

    return new Promise((resolve, reject) => {
        writer.on('finish', resolve);
        writer.on('error', reject);
    });
}

function getCategory(port) {
    const p = parseInt(port);
    
    if ([21, 23, 25, 80, 110, 143].includes(p)) return 'inseguro';
    if ([22, 443, 993, 995].includes(p)) return 'seguro';
    if ([53, 445, 3306, 3389, 5432, 8080].includes(p)) return 'precaucion';
    
    return 'inusual'; // Logic ported from PHP script
}

async function seedProtocolos() {
    console.log('🌱 Sembrando Protocolos (IANA)...');
    
    const localFile = path.join(__dirname, '../../database/seed/service-names-port-numbers.csv');
    
    if (!fs.existsSync(localFile)) {
        try {
            await downloadFile(IANA_URL, localFile);
        } catch (e) {
            console.error('❌ Error descargando IANA:', e.message);
            // Fallback empty if fail? Or return.
            // Let's return to avoid crashing if critical file missing
            if (!fs.existsSync(localFile)) return;
        }
    } else {
        console.log('📂 Usando archivo IANA local.');
    }

    const connection = await createConnection(true);
    
    try {
        let count = 0;
        let batch = [];
        const promises = [];

        console.log('⏳ Procesando CSV...');
        
        // We use a promise wrapper for the CSV stream
        await new Promise((resolve, reject) => {
            fs.createReadStream(localFile)
                .pipe(csv())
                .on('data', (row) => {
                    // CSV Headers usually: "Service Name", "Port Number", "Transport Protocol", "Description"
                    // csv-parser uses header keys. We need to be careful with keys.
                    // The IANA csv has headers: Service Name,Port Number,Transport Protocol,Description,Assignee,Contact,Registration Date,Modification Date,Reference,Service Code,Known Unauthorized Uses,Assignment Notes
                    
                    const serviceName = row['Service Name'];
                    const portNumber = row['Port Number'];
                    const description = row['Description'] || '';

                    if (portNumber && serviceName && !isNaN(portNumber)) {
                        const categoria = getCategory(portNumber);
                        
                        // Truncate description to 255 chars as per SQL likely
                        const desc = description.substring(0, 255);

                        batch.push([portNumber, serviceName, categoria, desc]);
                        count++;

                        if (batch.length >= EXEC_BATCH_SIZE) {
                            // Pause stream? csv-parser doesn't pause easily with async db calls in 'data'.
                            // Better to push to array and bulk insert often.
                            // However, 'data' is sync. If we await here, we block the stream processing 
                            // IF we were using an async iterator. With .on('data'), we can't await easily.
                            // For simplicity with this library, we might accumulate a lot in memory if we are not careful.
                            // But IANA list is ~5MB text, it fits in memory. 
                            // Let's accumulate all valid then batch insert? 
                            // Or use async iterator (available in newer node).
                        }
                    }
                })
                .on('end', () => {
                   resolve();
                })
                .on('error', reject);
        });

        // Batch insert loop
        console.log(`\n📦 Insertando ${batch.length} registros...`);
        
        for (let i = 0; i < batch.length; i += EXEC_BATCH_SIZE) {
            const chunk = batch.slice(i, i + EXEC_BATCH_SIZE);
            await connection.query(
                'INSERT IGNORE INTO protocolos (numero, nombre, categoria, descripcion) VALUES ?', 
                [chunk]
            );
            process.stdout.write(`\r✅ Insertados: ${i + chunk.length} / ${batch.length}`);
        }
        
        console.log(`\n✅ Sembrado de Protocolos completado.`);

    } catch (error) {
        console.error('\n❌ Error durante el sembrado:', error);
    } finally {
        await connection.end();
    }
}

if (require.main === module) {
    seedProtocolos();
}

module.exports = seedProtocolos;
