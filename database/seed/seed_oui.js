const fs = require('fs');
const readline = require('readline');
const path = require('path');
const axios = require('axios');
const { createConnection } = require('../lib/db');

const EXEC_BATCH_SIZE = 1000;
const OUI_URL = 'http://standards-oui.ieee.org/oui/oui.txt';

async function downloadFile(url, dest) {
    console.log('📥 Descargando lista OUI...');
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

async function seedOui() {
    console.log('🌱 Sembrando Fabricantes (OUI)...');
    
    const localFile = path.join(__dirname, '../../database/seed/oui.txt');
    
    if (!fs.existsSync(localFile)) {
        try {
            await downloadFile(OUI_URL, localFile);
        } catch (e) {
            console.error('❌ Error descargando OUI:', e.message);
            return;
        }
    } else {
        console.log('📂 Usando archivo OUI local.');
    }

    const connection = await createConnection(true);
    
    try {
        const fileStream = fs.createReadStream(localFile);
        const rl = readline.createInterface({
            input: fileStream,
            crlfDelay: Infinity
        });

        let count = 0;
        let batch = [];
        const regex = /^([0-9A-F]{2}-[0-9A-F]{2}-[0-9A-F]{2})\s+\(hex\)\s+(.+)$/i;

        console.log('⏳ Procesando líneas...');

        for await (const line of rl) {
            const match = line.match(regex);
            if (match) {
                const oui = match[1].replace(/-/g, '');
                const name = match[2].trim();
                
                batch.push([name, oui]);
                count++;

                if (batch.length >= EXEC_BATCH_SIZE) {
                    await connection.query('INSERT IGNORE INTO fabricantes (nombre, oui_mac) VALUES ?', [batch]);
                    batch = [];
                    process.stdout.write(`\r⏳ Insertados: ${count}`);
                }
            }
        }

        if (batch.length > 0) {
            await connection.query('INSERT IGNORE INTO fabricantes (nombre, oui_mac) VALUES ?', [batch]);
        }

        console.log(`\n✅ Sembrado de OUI completado. Total: ${count}`);

    } catch (error) {
        console.error('\n❌ Error durante el sembrado:', error);
    } finally {
        await connection.end();
    }
}

if (require.main === module) {
    seedOui();
}

module.exports = seedOui;
