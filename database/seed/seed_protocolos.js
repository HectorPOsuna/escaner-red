const fs = require('fs');
const path = require('path');
const axios = require('axios');
const csv = require('csv-parser');
const { createConnection } = require('../lib/db');

const EXEC_BATCH_SIZE = 500;
const IANA_URL = 'https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.csv';

// Mapeo extenso de clasificaciones inteligentes
const PORT_CATEGORIES = {
    // Protocolos seguros (cifrados)
    seguro: [
        // SSH/SSL/TLS
        22, 443, 465, 563, 585, 614, 636, 989, 990, 992, 993, 994, 995,
        2222, 2376, 2377, 2379, 2380, 8443, 9443,
        
        // VPN
        500, 1701, 1723, 4500, 1194,
        
        // Bases de datos seguras
        1433, 1434, 3306, 5432, 1521, 27017, 27018, 27019, 5984,
        
        // Otros seguros
        873, 3000, 5000, 5671, 5672, 61614, 61616
    ],
    
    // Protocolos inseguros (sin cifrado)
    inseguro: [
        // HTTP/FTP/Telnet sin cifrar
        21, 23, 25, 80, 110, 143, 161, 162, 389, 512, 513, 514,
        
        // Otros sin cifrar
        67, 68, 69, 111, 135, 137, 138, 139, 445, 2049, 3306,
        
        // Puerto comunes sin cifrar
        8080, 8888, 9000, 9090, 10000
    ],
    
    // Servicios esenciales de red
    esencial: [
        53, 67, 68, 123, 161, 162,  // DNS, DHCP, NTP, SNMP
        546, 547,                   // DHCPv6
        5353,                       // mDNS
        1900                        // UPnP
    ],
    
    // Bases de datos
    base_de_datos: [
        1433, 1434,                 // SQL Server
        1521, 1522,                 // Oracle
        3306,                       // MySQL
        5432, 5433,                 // PostgreSQL
        27017, 27018, 27019,        // MongoDB
        5984,                       // CouchDB
        6379,                       // Redis
        9200, 9300,                 // Elasticsearch
        11211,                      // Memcached
        2424, 2480,                 // OrientDB
        8087, 8091, 8092, 8093,     // Couchbase
        9042,                       // Cassandra
        27017                       // MongoDB (repetido para claridad)
    ],
    
    // Correo electrónico
    correo: [
        25, 465, 587,               // SMTP
        110, 995,                   // POP3
        143, 993,                   // IMAP
        26, 2525                    // SMTP alternativos
    ],
    
    // Gestión/administración
    gestion: [
        22, 23,                     // SSH/Telnet
        3389,                       // RDP
        5900, 5901,                 // VNC
        10000,                      // Webmin
        8080, 8443,                 // Paneles web
        9000, 9001,                 // Portainer/PhpMyAdmin
        9090                        // Prometheus
    ],
    
    // Acceso remoto
    remoto: [
        22,                         // SSH
        3389,                       // RDP
        5900, 5901, 5902,           // VNC
        5800, 5801,                 // VNC over HTTP
        23,                         // Telnet
        5631, 5632                  // pcAnywhere
    ],
    
    // Multimedia/Streaming
    multimedia: [
        554, 8554,                  // RTSP
        1935,                       // RTMP
        3478, 3479,                 // STUN/TURN
        5060, 5061,                 // SIP
        8000, 8001, 8002,           // Shoutcast/Icecast
        8080, 8081,                 // HTTP streaming
        9000, 9001                  // Plex/Emby
    ],
    
    // Juegos en línea
    juegos: [
        27015, 27016, 27017, 27018, 27019, 27020, // Steam/Valve
        25565,                       // Minecraft
        3724,                        // World of Warcraft
        6112,                        // Blizzard
        7777, 7778,                  // Unreal Tournament
        2302, 2303,                  // Halo
        28910, 29900                 // Call of Duty
    ],
    
    // VoIP
    voz_ip: [
        5060, 5061,                 // SIP
        1720,                       // H.323
        10000, 20000,               // RTP
        3478, 3479, 5349            // STUN/TURN
    ],
    
    // Compartición de archivos
    archivos: [
        21, 20,                     // FTP
        69,                         // TFTP
        139, 445,                   // SMB/CIFS
        2049,                       // NFS
        873,                        // Rsync
        548,                        // AFP
        9000                        // HTTP File Server
    ],
    
    // Monitoreo
    monitoreo: [
        161, 162,                   // SNMP
        2000,                       // Cisco SCCP
        5666,                       // Nagios
        9090,                       // Prometheus
        9100,                       // Node Exporter
        9182,                       // Pushgateway
        10050, 10051                // Zabbix
    ],
    
    // Virtualización/Containers
    virtualizacion: [
        2375, 2376,                 // Docker
        2377, 2379, 2380,           // Docker Swarm
        6443,                       // Kubernetes API
        8080,                       // Kubernetes Dashboard
        9093,                       // Alertmanager
        10250,                      // Kubelet
        30000                       // NodePort
    ],
    
    // Desarrollo/Depuración
    desarrollo: [
        3000,                       // Node.js
        4200,                       // Angular
        5000,                       // Flask
        8000, 8001,                 // Django/development
        8080, 8081,                 // Development servers
        9000,                       // PHP development
        9229,                       // Node.js debug
        35729                       // LiveReload
    ],
    
    // Impresión
    impresion: [
        515,                        // LPD
        631, 9100,                  // IPP
        161, 162,                   // SNMP para impresoras
        9220                        // Canon
    ],
    
    // Backup/Sincronización
    backup: [
        873,                        // Rsync
        22,                         // SSH para backup
        3306,                       // MySQL dump
        5432,                       // PostgreSQL dump
        27017,                      // MongoDB dump
        8080                        // Web backup interfaces
    ]
};

// Función inteligente de clasificación
function getIntelligentCategory(port, serviceName, description) {
    const portNum = parseInt(port);
    
    // Buscar en todas las categorías
    for (const [category, ports] of Object.entries(PORT_CATEGORIES)) {
        if (ports.includes(portNum)) {
            return category;
        }
    }
    
    // Clasificación por nombre del servicio
    const serviceLower = (serviceName || '').toLowerCase();
    const descLower = (description || '').toLowerCase();
    
    // Por nombre del servicio
    if (serviceLower.includes('http') || serviceLower.includes('www')) {
        return portNum === 443 || portNum === 8443 ? 'seguro' : 'inseguro';
    }
    
    if (serviceLower.includes('ssh') || serviceLower.includes('secure')) {
        return 'seguro';
    }
    
    if (serviceLower.includes('telnet') || serviceLower.includes('ftp') && !serviceLower.includes('sftp')) {
        return 'inseguro';
    }
    
    if (serviceLower.includes('smtp') || serviceLower.includes('pop') || serviceLower.includes('imap')) {
        return 'correo';
    }
    
    if (serviceLower.includes('sql') || serviceLower.includes('db') || serviceLower.includes('database')) {
        return 'base_de_datos';
    }
    
    if (serviceLower.includes('dns') || serviceLower.includes('dhcp') || serviceLower.includes('ntp')) {
        return 'esencial';
    }
    
    if (serviceLower.includes('rdp') || serviceLower.includes('remote') || serviceLower.includes('vnc')) {
        return 'remoto';
    }
    
    if (serviceLower.includes('game') || serviceLower.includes('steam') || serviceLower.includes('minecraft')) {
        return 'juegos';
    }
    
    if (serviceLower.includes('voip') || serviceLower.includes('sip') || serviceLower.includes('rtp')) {
        return 'voz_ip';
    }
    
    if (serviceLower.includes('stream') || serviceLower.includes('media') || serviceLower.includes('video')) {
        return 'multimedia';
    }
    
    if (serviceLower.includes('monitor') || serviceLower.includes('snmp') || serviceLower.includes('zabbix')) {
        return 'monitoreo';
    }
    
    if (serviceLower.includes('docker') || serviceLower.includes('kubernetes') || serviceLower.includes('container')) {
        return 'virtualizacion';
    }
    
    if (serviceLower.includes('print') || serviceLower.includes('ipp') || serviceLower.includes('lpd')) {
        return 'impresion';
    }
    
    // Por rango de puertos
    if (portNum >= 0 && portNum <= 1023) return 'esencial';       // Puertos bien conocidos
    if (portNum >= 1024 && portNum <= 49151) return 'inusual';    // Puertos registrados
    if (portNum >= 49152 && portNum <= 65535) return 'reservado'; // Puertos dinámicos/privados
    
    return 'inusual';
}

// Mapeo de prioridades (para cuando un puerto pueda tener múltiples categorías)
const CATEGORY_PRIORITY = {
    'seguro': 1,
    'inseguro': 2,
    'esencial': 3,
    'base_de_datos': 4,
    'correo': 5,
    'remoto': 6,
    'gestion': 7,
    'voz_ip': 8,
    'multimedia': 9,
    'juegos': 10,
    'archivos': 11,
    'monitoreo': 12,
    'virtualizacion': 13,
    'desarrollo': 14,
    'impresion': 15,
    'backup': 16,
    'reservado': 17,
    'inusual': 18
};

// Función para determinar la mejor categoría cuando hay conflicto
function resolveCategoryConflict(port, serviceName) {
    const portNum = parseInt(port);
    const possibleCategories = [];
    
    // Encontrar todas las categorías posibles
    for (const [category, ports] of Object.entries(PORT_CATEGORIES)) {
        if (ports.includes(portNum)) {
            possibleCategories.push(category);
        }
    }
    
    // Si solo una, retornarla
    if (possibleCategories.length === 1) {
        return possibleCategories[0];
    }
    
    // Si múltiples, elegir por prioridad
    if (possibleCategories.length > 1) {
        return possibleCategories.sort((a, b) => 
            CATEGORY_PRIORITY[a] - CATEGORY_PRIORITY[b]
        )[0];
    }
    
    // Si ninguna, clasificar por nombre
    return getIntelligentCategory(port, serviceName, '');
}

async function seedProtocolos() {
    console.log('🌱 Sembrando Protocolos con Clasificación Inteligente...');
    
    const localFile = path.join(__dirname, '../../database/seed/service-names-port-numbers.csv');
    
    if (!fs.existsSync(localFile)) {
        try {
            console.log('📥 Descargando lista IANA desde:', IANA_URL);
            await downloadFile(IANA_URL, localFile);
            console.log('✅ Descarga completa');
        } catch (e) {
            console.error('❌ Error descargando IANA:', e.message);
            return;
        }
    } else {
        console.log('📂 Usando archivo IANA local.');
    }

    const connection = await createConnection(true);
    
    try {
        let totalRecords = 0;
        let insertedRecords = 0;
        const batch = [];
        
        console.log('⏳ Procesando CSV y clasificando puertos...');
        
        // Leer y procesar CSV
        await new Promise((resolve, reject) => {
            fs.createReadStream(localFile)
                .pipe(csv())
                .on('data', (row) => {
                    totalRecords++;
                    
                    const serviceName = row['Service Name'] || '';
                    const portNumber = row['Port Number'];
                    const transport = row['Transport Protocol'] || '';
                    const description = row['Description'] || '';
                    
                    // Validar que sea un puerto numérico válido
                    if (!portNumber || isNaN(parseInt(portNumber))) {
                        return;
                    }
                    
                    const port = parseInt(portNumber);
                    
                    // Solo procesar puertos válidos (1-65535)
                    if (port < 1 || port > 65535) {
                        return;
                    }
                    
                    // Determinar categoría inteligente
                    const categoria = resolveCategoryConflict(port, serviceName);
                    
                    // Limitar longitudes para BD
                    const nombre = serviceName.substring(0, 50);
                    const desc = description.substring(0, 255);
                    
                    // Agregar al batch
                    batch.push([port, nombre, categoria, desc]);
                    
                    // Mostrar progreso cada 1000 registros
                    if (totalRecords % 1000 === 0) {
                        process.stdout.write(`\r📊 Procesados: ${totalRecords} | Clasificados: ${batch.length}`);
                    }
                })
                .on('end', () => {
                    console.log(`\n✅ CSV procesado. Total registros: ${totalRecords}`);
                    console.log(`📦 Registros válidos para insertar: ${batch.length}`);
                    resolve();
                })
                .on('error', reject);
        });

        // Insertar en lotes
        console.log('💾 Insertando registros en base de datos...');
        
        for (let i = 0; i < batch.length; i += EXEC_BATCH_SIZE) {
            const chunk = batch.slice(i, i + EXEC_BATCH_SIZE);
            
            try {
                await connection.query(
                    'INSERT IGNORE INTO protocolos (numero, nombre, categoria, descripcion) VALUES ?',
                    [chunk]
                );
                
                insertedRecords += chunk.length;
                process.stdout.write(`\r✅ Insertados: ${insertedRecords} / ${batch.length}`);
                
            } catch (error) {
                console.error(`\n❌ Error insertando lote ${i}-${i+chunk.length}:`, error.message);
                // Continuar con siguiente lote
                continue;
            }
        }
        
        console.log(`\n\n📊 RESUMEN FINAL:`);
        console.log(`   Total procesados del CSV: ${totalRecords}`);
        console.log(`   Registros válidos: ${batch.length}`);
        console.log(`   Registros insertados: ${insertedRecords}`);
        
        // Estadísticas por categoría
        console.log(`\n📈 DISTRIBUCIÓN POR CATEGORÍA:`);
        const categoryStats = {};
        batch.forEach(item => {
            const category = item[2]; // índice 2 es la categoría
            categoryStats[category] = (categoryStats[category] || 0) + 1;
        });
        
        Object.entries(categoryStats)
            .sort((a, b) => b[1] - a[1])
            .forEach(([category, count]) => {
                const percentage = ((count / batch.length) * 100).toFixed(1);
                console.log(`   ${category}: ${count} (${percentage}%)`);
            });

    } catch (error) {
        console.error('\n❌ Error durante el sembrado:', error);
    } finally {
        await connection.end();
    }
}

// Función auxiliar para descargar
async function downloadFile(url, dest) {
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

if (require.main === module) {
    seedProtocolos();
}

module.exports = seedProtocolos;