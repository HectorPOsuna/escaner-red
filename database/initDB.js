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
        
        // 2. Ejecutar migración inicial (Esquema completo)
        const migrationPath = path.join(__dirname, 'migrations', '007_initial_schema.sql');
        console.log(`📄 Ejecutando migración: ${path.basename(migrationPath)}`);
        await executeSQLFile(migrationPath);
        
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
