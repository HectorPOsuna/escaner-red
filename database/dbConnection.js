const mysql = require('mysql2/promise');
const fs = require('fs').promises;
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

/**
 * Configuración de la conexión a MySQL
 */
const dbConfig = {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    multipleStatements: true // Permite ejecutar múltiples sentencias SQL
};

/**
 * Crea una conexión a la base de datos
 * @returns {Promise<mysql.Connection>}
 */
async function createConnection() {
    try {
        const connection = await mysql.createConnection(dbConfig);
        console.log('✅ Conexión exitosa a MySQL');
        return connection;
    } catch (error) {
        console.error('❌ Error al conectar a MySQL:', error.message);
        throw error;
    }
}

/**
 * Ejecuta un archivo SQL en la base de datos
 * @param {string} sqlFilePath - Ruta al archivo SQL
 * @returns {Promise<void>}
 */
async function executeSQLFile(sqlFilePath) {
    let connection;
    
    try {
        // Leer el archivo SQL
        const sqlContent = await fs.readFile(sqlFilePath, 'utf8');
        console.log(`📄 Leyendo archivo: ${path.basename(sqlFilePath)}`);
        
        // Crear conexión
        connection = await createConnection();
        
        // Ejecutar el SQL
        console.log('⚙️  Ejecutando SQL...');
        const [results] = await connection.query(sqlContent);
        
        console.log('✅ SQL ejecutado exitosamente');
        console.log('📊 Resultados:', results);
        
        return results;
        
    } catch (error) {
        console.error('❌ Error al ejecutar SQL:', error.message);
        throw error;
    } finally {
        if (connection) {
            await connection.end();
            console.log('🔌 Conexión cerrada');
        }
    }
}

/**
 * Ejecuta todos los archivos SQL en un directorio
 * @param {string} directoryPath - Ruta al directorio con archivos SQL
 * @returns {Promise<void>}
 */
async function executeSQLDirectory(directoryPath) {
    try {
        const files = await fs.readdir(directoryPath);
        const sqlFiles = files.filter(file => file.endsWith('.sql'));
        
        console.log(`📁 Encontrados ${sqlFiles.length} archivos SQL en ${directoryPath}`);
        
        for (const file of sqlFiles) {
            const filePath = path.join(directoryPath, file);
            console.log(`\n${'='.repeat(50)}`);
            await executeSQLFile(filePath);
        }
        
        console.log(`\n✅ Todos los archivos SQL ejecutados correctamente`);
        
    } catch (error) {
        console.error('❌ Error al procesar directorio:', error.message);
        throw error;
    }
}

/**
 * Verifica la conexión a la base de datos
 * @returns {Promise<boolean>}
 */
async function testConnection() {
    let connection;
    
    try {
        connection = await createConnection();
        const [rows] = await connection.execute('SELECT 1 + 1 AS result');
        console.log('✅ Test de conexión exitoso:', rows[0]);
        return true;
    } catch (error) {
        console.error('❌ Test de conexión fallido:', error.message);
        return false;
    } finally {
        if (connection) {
            await connection.end();
        }
    }
}

module.exports = {
    createConnection,
    executeSQLFile,
    executeSQLDirectory,
    testConnection
};
