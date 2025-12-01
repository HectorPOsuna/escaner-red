const { createConnection } = require('./dbConnection');
const fs = require('fs');
const path = require('path');

const OUI_URL = 'http://standards-oui.ieee.org/oui/oui.txt';
const BATCH_SIZE = 1000;

async function fetchOuiData() {
    console.log(`📥 Descargando lista OUI desde ${OUI_URL}...`);
    try {
        const response = await fetch(OUI_URL);
        if (!response.ok) {
            throw new Error(`Error HTTP: ${response.status}`);
        }
        return await response.text();
    } catch (error) {
        console.error('❌ Error descargando datos:', error.message);
        throw error;
    }
}

function parseOuiData(textData) {
    console.log('🔄 Procesando datos...');
    console.log('🔍 Primeras 5 líneas del archivo descargado:');
    console.log(textData.substring(0, 500)); // Imprimir primeros 500 caracteres
    
    const lines = textData.split('\n');
    const manufacturers = [];
    const regex = /^([0-9A-F]{2}-[0-9A-F]{2}-[0-9A-F]{2})\s+\(hex\)\s+(.+)$/i;

    for (const rawLine of lines) {
        const line = rawLine.trim();
        if (!line) continue;
        
        const match = line.match(regex);
        if (match) {
            const rawOui = match[1];
            const name = match[2].trim();
            
            // Normalizar OUI: 00-00-00 -> 000000
            const cleanOui = rawOui.replace(/-/g, '');
            
            manufacturers.push({
                oui: cleanOui,
                name: name
            });
        }
    }
    
    console.log(`✅ Se encontraron ${manufacturers.length} fabricantes válidos.`);
    return manufacturers;
}

async function seedDatabase() {
    let connection;
    try {
        // 1. Obtener datos
        const textData = await fetchOuiData();
        const manufacturers = parseOuiData(textData);
        
        if (manufacturers.length === 0) {
            console.log('⚠️ No se encontraron datos para insertar.');
            return;
        }

        // 2. Conectar a BD
        connection = await createConnection();
        
        console.log(`💾 Iniciando inserción en base de datos (Lotes de ${BATCH_SIZE})...`);
        
        // 3. Insertar por lotes
        let processed = 0;
        let inserted = 0;
        
        for (let i = 0; i < manufacturers.length; i += BATCH_SIZE) {
            const batch = manufacturers.slice(i, i + BATCH_SIZE);
            
            // Construir query masivo
            // INSERT IGNORE para saltar duplicados sin error
            const values = batch.map(m => [m.name, m.oui]);
            
            // Nota: mysql2 helper 'query' puede manejar arrays de arrays para bulk insert
            const sql = 'INSERT IGNORE INTO fabricantes (nombre, oui_mac) VALUES ?';
            
            const [result] = await connection.query(sql, [values]);
            
            inserted += result.affectedRows;
            processed += batch.length;
            
            process.stdout.write(`\r⏳ Procesados: ${processed}/${manufacturers.length} | Insertados: ${inserted}`);
        }
        
        console.log(`\n\n🎉 Proceso completado!`);
        console.log(`Total procesados: ${processed}`);
        console.log(`Nuevos insertados: ${inserted}`);
        
    } catch (error) {
        console.error('\n❌ Error fatal:', error);
    } finally {
        if (connection) {
            await connection.end();
            console.log('🔌 Conexión cerrada');
        }
    }
}

// Ejecutar
if (require.main === module) {
    seedDatabase();
}

module.exports = { seedDatabase };
