const { executeSQLFile, executeSQLDirectory, testConnection } = require('./dbConnection');
const path = require('path');

/**
 * Script para inicializar la base de datos
 * Ejecuta todos los archivos SQL necesarios para crear las tablas
 */
async function initializeDatabase() {
    console.log('🚀 Iniciando configuración de base de datos...\n');
    
    try {
        // 1. Verificar conexión
        console.log('1️⃣ Verificando conexión a la base de datos...');
        const isConnected = await testConnection();
        
        if (!isConnected) {
            console.error('❌ No se pudo conectar a la base de datos');
            process.exit(1);
        }
        
        console.log('\n2️⃣ Ejecutando archivos SQL...\n');
        
        // 2. Ejecutar archivo de creación de tabla conflictos
        const sqlFilePath = path.join(__dirname, 'create_conflictos_table.sql');
        await executeSQLFile(sqlFilePath);
        
        // Alternativa: Ejecutar todos los archivos SQL del directorio
        // await executeSQLDirectory(__dirname);
        
        console.log('\n✅ Base de datos inicializada correctamente');
        
    } catch (error) {
        console.error('\n❌ Error al inicializar la base de datos:', error.message);
        process.exit(1);
    }
}

// Ejecutar si se llama directamente
if (require.main === module) {
    initializeDatabase();
}

module.exports = { initializeDatabase };
