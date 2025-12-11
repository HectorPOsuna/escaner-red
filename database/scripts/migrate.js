const fs = require('fs').promises;
const path = require('path');
const { createConnection, dbName } = require('../lib/db');

async function runMigration() {
    console.log('🚀 Iniciando migración de base de datos...');
    let connection;

    try {
        // 1. Crear Base de Datos
        connection = await createConnection(false);
        await connection.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
        console.log(`✅ Base de datos '${dbName}' verificada/creada.`);
        await connection.end();

        // 2. Ejecutar SQL
        connection = await createConnection(true);
        
        const sqlPath = path.join(__dirname, '../../database/migrations/init_database.sql');
        const sql = await fs.readFile(sqlPath, 'utf8');

        console.log('📜 Ejecutando script SQL...');
        // mysql2 supports multipleStatements
        await connection.query(sql);
        
        console.log('✅ Tablas y estructuras creadas correctamente.');

    } catch (error) {
        console.error('❌ Error fatal en migración:', error);
        process.exit(1);
    } finally {
        if (connection) await connection.end();
    }
}

if (require.main === module) {
    runMigration();
}

module.exports = runMigration;
