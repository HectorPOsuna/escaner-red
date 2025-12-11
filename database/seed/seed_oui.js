const fs = require('fs');
const readline = require('readline');
const path = require('path');
const https = require('https');
const { createConnection } = require('../lib/db');

const EXEC_BATCH_SIZE = 2000; // Aumentado para mejor performance

// Múltiples fuentes de OUI (prioridad)
const OUI_SOURCES = [
    {
        name: 'IEEE Official',
        url: 'https://standards-oui.ieee.org/oui/oui.txt'
    },
    {
        name: 'IEEE Alternative',
        url: 'https://standards-oui.ieee.org/oui.txt'
    },
    {
        name: 'Wireshark',
        url: 'https://gitlab.com/wireshark/wireshark/-/raw/master/manuf'
    },
    {
        name: 'Linuxnet',
        url: 'https://linuxnet.ca/ieee/oui.txt'
    }
];

// Headers para evitar bloqueos
const REQUEST_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept': 'text/plain,text/html',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache'
};

async function downloadWithHttps(url, dest) {
    return new Promise((resolve, reject) => {
        console.log(`📥 Descargando desde: ${url}`);
        
        const request = https.get(url, { 
            headers: REQUEST_HEADERS,
            timeout: 60000 
        }, (response) => {
            // Verificar si es redirección
            if (response.statusCode === 301 || response.statusCode === 302) {
                const redirectUrl = response.headers.location;
                console.log(`↪️ Redirigiendo a: ${redirectUrl}`);
                return downloadWithHttps(redirectUrl, dest).then(resolve).catch(reject);
            }
            
            if (response.statusCode !== 200) {
                reject(new Error(`HTTP ${response.statusCode}`));
                return;
            }
            
            const fileStream = fs.createWriteStream(dest);
            let downloadedBytes = 0;
            const totalBytes = parseInt(response.headers['content-length'] || '0', 10);
            
            response.on('data', (chunk) => {
                downloadedBytes += chunk.length;
                if (totalBytes > 0) {
                    const percent = Math.round((downloadedBytes / totalBytes) * 100);
                    process.stdout.write(`\r📥 Descargando: ${percent}% (${Math.round(downloadedBytes / 1024)} KB)`);
                }
            });
            
            response.pipe(fileStream);
            
            fileStream.on('finish', () => {
                fileStream.close();
                console.log(`\n✅ Descarga completada: ${Math.round(downloadedBytes / 1024)} KB`);
                resolve();
            });
            
            fileStream.on('error', (err) => {
                fs.unlink(dest, () => {}); // Eliminar archivo parcial
                reject(err);
            });
        });
        
        request.on('error', reject);
        request.on('timeout', () => {
            request.destroy();
            reject(new Error('Timeout'));
        });
    });
}

async function tryDownloadFromSources(sources, dest) {
    for (const source of sources) {
        try {
            console.log(`\n🔄 Intentando fuente: ${source.name}...`);
            await downloadWithHttps(source.url, dest);
            return { success: true, source: source.name };
        } catch (error) {
            console.warn(`❌ Falló ${source.name}: ${error.message}`);
            // Esperar antes de intentar la siguiente fuente
            await new Promise(resolve => setTimeout(resolve, 2000));
            continue;
        }
    }
    return { success: false };
}

async function seedOui() {
    console.log('='.repeat(70));
    console.log('🌱 INICIANDO SEMBRADO MASIVO DE FABRICANTES OUI');
    console.log('='.repeat(70));
    
    const localFile = path.join(__dirname, '../../database/seed/oui.txt');
    const backupFile = path.join(__dirname, '../../database/seed/oui_backup.txt');
    const connection = await createConnection(true);
    
    let totalProcessed = 0;
    let totalInserted = 0;
    
    try {
        // 1. VERIFICAR Y DESCARGAR ARCHIVO OUI
        let fileExists = fs.existsSync(localFile);
        let fileSize = 0;
        
        if (fileExists) {
            fileSize = fs.statSync(localFile).size;
            console.log(`📂 Archivo OUI local encontrado: ${Math.round(fileSize / 1024)} KB`);
            
            // Si el archivo es muy pequeño (< 100KB), probablemente está incompleto
            if (fileSize < 100 * 1024) {
                console.log('⚠️ Archivo local muy pequeño. Intentando descargar uno nuevo...');
                fileExists = false;
            }
        }
        
        if (!fileExists) {
            console.log('\n🔄 No se encontró archivo OUI local. Descargando...');
            
            // Hacer backup si existe
            if (fs.existsSync(localFile)) {
                fs.copyFileSync(localFile, backupFile);
                console.log(`📦 Backup creado: ${backupFile}`);
            }
            
            const result = await tryDownloadFromSources(OUI_SOURCES, localFile);
            
            if (!result.success) {
                console.error('\n❌ Todas las fuentes fallaron. Usando fabricantes básicos...');
                await createBasicManufacturers(connection);
                return;
            }
            
            console.log(`✅ Descargado desde: ${result.source}`);
        }
        
        // 2. LEER Y PROCESAR EL ARCHIVO COMPLETO
        console.log('\n' + '='.repeat(70));
        console.log('⚙️  PROCESANDO ARCHIVO OUI COMPLETO');
        console.log('='.repeat(70));
        
        const fileStream = fs.createReadStream(localFile);
        const rl = readline.createInterface({
            input: fileStream,
            crlfDelay: Infinity
        });

        let batch = [];
        let batchNumber = 1;
        
        // Expresiones regulares para diferentes formatos
        const regexPatterns = [
            /^([0-9A-F]{2}-[0-9A-F]{2}-[0-9A-F]{2})\s+\(hex\)\s+(.+)$/i,  // 00-00-0C   (hex)		CISCO
            /^([0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2})\s+\(hex\)\s+(.+)$/i,   // 00:00:0C   (hex)		CISCO
            /^([0-9A-F]{6})\s+\(hex\)\s+(.+)$/i,                          // 00000C     (hex)		CISCO
            /^([0-9A-F]{2}-[0-9A-F]{2}-[0-9A-F]{2})\s+\(base 16\)\s+(.+)$/i, // Formato alternativo
        ];

        console.log('⏳ Procesando líneas (esto puede tomar varios minutos)...');
        
        let lineCount = 0;
        const startTime = Date.now();
        
        for await (const line of rl) {
            lineCount++;
            
            // Mostrar progreso cada 5000 líneas
            if (lineCount % 5000 === 0) {
                const elapsed = (Date.now() - startTime) / 1000;
                console.log(`⏱️  Líneas procesadas: ${lineCount.toLocaleString()} (${elapsed.toFixed(1)}s)`);
            }
            
            let match = null;
            let oui = null;
            let name = null;
            
            // Intentar todos los patrones
            for (const pattern of regexPatterns) {
                match = line.match(pattern);
                if (match) {
                    oui = match[1].replace(/[-:]/g, '').toUpperCase(); // Normalizar: quitar - o : y poner mayúsculas
                    name = match[2].trim();
                    break;
                }
            }
            
            if (oui && name && oui !== '000000') {
                // Limitar longitud del nombre si es necesario
                if (name.length > 150) {
                    name = name.substring(0, 147) + '...';
                }
                
                // Limpiar nombre (remover espacios extras)
                name = name.replace(/\s+/g, ' ').trim();
                
                batch.push([name, oui]);
                totalProcessed++;
                
                // Insertar cuando el batch esté lleno
                if (batch.length >= EXEC_BATCH_SIZE) {
                    await insertBatch(batch, connection, batchNumber);
                    totalInserted += batch.length;
                    batch = [];
                    batchNumber++;
                }
            }
        }
        
        // Insertar el último batch si queda algo
        if (batch.length > 0) {
            await insertBatch(batch, connection, batchNumber);
            totalInserted += batch.length;
        }
        
        const totalTime = (Date.now() - startTime) / 1000;
        
        console.log('\n' + '='.repeat(70));
        console.log('✅ PROCESO COMPLETADO');
        console.log('='.repeat(70));
        console.log(`📊 Estadísticas:`);
        console.log(`   • Líneas totales leídas: ${lineCount.toLocaleString()}`);
        console.log(`   • Fabricantes procesados: ${totalProcessed.toLocaleString()}`);
        console.log(`   • Fabricantes insertados: ${totalInserted.toLocaleString()}`);
        console.log(`   • Tiempo total: ${totalTime.toFixed(2)} segundos`);
        console.log(`   • Velocidad: ${Math.round(lineCount / totalTime)} líneas/segundo`);
        
        // 3. VERIFICAR TOTAL EN BASE DE DATOS
        const [finalCount] = await connection.query('SELECT COUNT(*) as count FROM fabricantes');
        console.log(`\n📦 Total fabricantes en base de datos: ${finalCount[0].count.toLocaleString()}`);
        
        // 4. VERIFICAR ALGUNOS EJEMPLOS
        await verifySampleLookups(connection);
        
    } catch (error) {
        console.error('\n❌ ERROR CRÍTICO:', error);
        console.error(error.stack);
        
        // Intentar crear fabricantes básicos como fallback
        try {
            console.log('\n🔄 Intentando crear fabricantes básicos como fallback...');
            await createBasicManufacturers(connection);
        } catch (fallbackError) {
            console.error('❌ Fallback también falló:', fallbackError.message);
        }
        
    } finally {
        await connection.end();
        console.log('\n' + '='.repeat(70));
        console.log('🏁 SEMBRADO FINALIZADO');
        console.log('='.repeat(70));
    }
}

async function insertBatch(batch, connection, batchNumber) {
    try {
        await connection.query(
            'INSERT IGNORE INTO fabricantes (nombre, oui_mac) VALUES ?', 
            [batch]
        );
        console.log(`✅ Batch ${batchNumber}: Insertados ${batch.length.toLocaleString()} fabricantes`);
    } catch (error) {
        console.error(`❌ Error en batch ${batchNumber}:`, error.message);
        // Continuar con el siguiente batch
    }
}

async function createBasicManufacturers(connection) {
    console.log('🛠️ Creando fabricantes básicos...');
    
    const basicManufacturers = [
        ['Desconocido', '000000'],
        ['Cisco Systems, Inc.', '00000C'],
        ['Intel Corporation', '0000C9'],
        ['Apple, Inc.', '00007B'],
        ['Dell Inc.', '001DE1'],
        ['Hewlett Packard', '001A4B'],
        ['Samsung Electronics', '001D25'],
        ['Microsoft Corporation', '000D3A'],
        ['TP-LINK TECHNOLOGIES', '001478'],
        ['Google, Inc.', '3C5AB4'],
        ['ASUSTek COMPUTER INC.', '001D60'],
        ['LG Electronics', '001F6B'],
        ['Sony Corporation', '00065B'],
        ['Lenovo', '0017A4'],
        ['Huawei Technologies', '002568'],
        ['Xiaomi Communications', '64B853'],
        ['Netgear', '0015F2'],
        ['D-Link Corporation', '0015E9'],
        ['IBM Corporation', '00055D'],
        ['VMware, Inc.', '000C29'],
        ['Amazon Technologies Inc.', '0C47C9'],
        ['Broadcom', '001517'],
        ['Qualcomm', '001374'],
        ['Nvidia Corporation', '001B21'],
        ['Realtek Semiconductor', '0012FE'],
        ['Marvell Semiconductor', '008865'],
        ['Texas Instruments', '000476'],
        ['Raspberry Pi Trading', 'B827EB'],
        ['Aruba Networks', '0024A5'],
        ['Ubiquiti Networks', '002722'],
        ['MikroTik', '4C5E0C'],
        ['ZTE Corporation', '001C1D'],
        ['Nokia Corporation', '001E3B'],
        ['Ericsson', '0016BC'],
        ['Motorola Solutions', '0000C0'],
        ['Brocade Communications', '001B17'],
        ['Juniper Networks', '009069'],
        ['Alcatel-Lucent', '00147D'],
        ['Fujitsu Limited', '00000E'],
        ['Toshiba Corporation', '000039'],
        ['Canon Inc.', '0000FE'],
        ['Epson', '0000C8'],
        ['Brother Industries', '0000E8'],
        ['Lexmark International', '000CF1'],
        ['Kyocera Corporation', '0006F6'],
        ['Ricoh Company', '00000F'],
        ['Sharp Corporation', '000086'],
        ['Panasonic Corporation', '0000CE'],
        ['Philips Electronics', '0000F0'],
        ['Siemens AG', '000003'],
        ['General Electric', '0002A3'],
        ['Rockwell Automation', '0000A6'],
        ['Schneider Electric', '00A0D1'],
        ['ABB Group', '0001C7'],
        ['Mitsubishi Electric', '0000C7'],
        ['Omron Corporation', '0000FD'],
        ['Yokogawa Electric', '0001E8'],
        ['National Instruments', '000014'],
        ['Keysight Technologies', '0004CF'],
        ['Rohde & Schwarz', '0007C2'],
        ['Tektronix, Inc.', '00000D'],
        ['Fluke Corporation', '000A5E'],
        ['Agilent Technologies', '0003BA'],
        ['Advantest Corporation', '0000E2']
    ];
    
    try {
        await connection.query(
            'INSERT IGNORE INTO fabricantes (nombre, oui_mac) VALUES ?', 
            [basicManufacturers]
        );
        console.log(`✅ Insertados ${basicManufacturers.length} fabricantes básicos`);
    } catch (error) {
        console.error('❌ Error insertando fabricantes básicos:', error.message);
        throw error;
    }
}

async function verifySampleLookups(connection) {
    console.log('\n🔍 Verificando búsquedas de ejemplo...');
    
    const testCases = [
        { mac: '00:0C:29:AB:CD:EF', expected: 'VMware, Inc.' },
        { mac: '00:50:56:C0:00:08', expected: 'VMware, Inc.' },
        { mac: '00:1B:63:84:45:E6', expected: 'Apple, Inc.' },
        { mac: '00:1D:60:F9:3A:7C', expected: 'ASUSTek COMPUTER INC.' },
        { mac: '00:25:4B:AB:CD:EF', expected: 'Dell Inc.' },
        { mac: '08:00:27:AB:CD:EF', expected: 'Cadmus Computer Systems' },
        { mac: '3C:5A:B4:12:34:56', expected: 'Google, Inc.' },
        { mac: 'B8:27:EB:12:34:56', expected: 'Raspberry Pi Trading' },
        { mac: '00:15:5D:12:34:56', expected: 'Microsoft Corporation' },
        { mac: '00:1A:11:12:34:56', expected: 'Google, Inc.' }
    ];
    
    let found = 0;
    let notFound = 0;
    
    for (const test of testCases) {
        const oui = test.mac.replace(/:/g, '').substring(0, 6).toUpperCase();
        const [result] = await connection.query(
            'SELECT nombre FROM fabricantes WHERE oui_mac = ?', 
            [oui]
        );
        
        if (result.length > 0) {
            console.log(`  ✅ ${test.mac} → ${result[0].nombre}`);
            found++;
        } else {
            console.log(`  ❌ ${test.mac} → NO ENCONTRADO (OUI: ${oui})`);
            notFound++;
        }
    }
    
    console.log(`\n📊 Resultado: ${found} encontrados, ${notFound} no encontrados`);
    
    if (notFound > 0) {
        console.log('⚠️ Algunas OUIs no se encontraron. Considera descargar un archivo OUI más completo.');
    }
}

// Función para verificar el estado actual
async function checkCurrentStatus() {
    console.log('\n📋 VERIFICANDO ESTADO ACTUAL');
    console.log('='.repeat(50));
    
    const connection = await createConnection(true);
    
    try {
        // Verificar conteo
        const [countRows] = await connection.query('SELECT COUNT(*) as count FROM fabricantes');
        console.log(`Fabricantes en BD: ${countRows[0].count.toLocaleString()}`);
        
        // Verificar tamaño del archivo OUI local
        const ouiFile = path.join(__dirname, '../../database/seed/oui.txt');
        if (fs.existsSync(ouiFile)) {
            const stats = fs.statSync(ouiFile);
            console.log(`Archivo OUI local: ${Math.round(stats.size / 1024)} KB`);
        } else {
            console.log('Archivo OUI local: NO EXISTE');
        }
        
        // Mostrar algunos fabricantes
        const [samples] = await connection.query('SELECT oui_mac, nombre FROM fabricantes ORDER BY RAND() LIMIT 10');
        console.log('\n🔢 Muestra aleatoria de fabricantes:');
        samples.forEach(f => console.log(`  ${f.oui_mac} → ${f.nombre}`));
        
    } catch (error) {
        console.error('Error verificando estado:', error);
    } finally {
        await connection.end();
    }
}

// Comando principal
if (require.main === module) {
    const command = process.argv[2];
    
    switch (command) {
        case 'status':
            checkCurrentStatus();
            break;
        case 'verify':
            (async () => {
                const conn = await createConnection(true);
                await verifySampleLookups(conn);
                await conn.end();
            })();
            break;
        case 'basic':
            (async () => {
                const conn = await createConnection(true);
                await createBasicManufacturers(conn);
                await conn.end();
            })();
            break;
        default:
            seedOui();
    }
}

module.exports = { seedOui, checkCurrentStatus, verifySampleLookups };