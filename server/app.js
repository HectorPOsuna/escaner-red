const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const path = require('path');
const dotenv = require('dotenv');

// Cargar variables de entorno desde la raíz del proyecto
dotenv.config({ path: path.resolve(__dirname, '../.env') });

const scanRoutes = require('./routes/scan');
const { testConnection } = require('../database/dbConnection');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' })); // Aumentar límite para reportes grandes

// Rutas
app.use('/api', scanRoutes);

// Health Check
app.get('/health', async (req, res) => {
    const dbStatus = await testConnection();
    res.json({ 
        status: 'UP', 
        database: dbStatus ? 'Connected' : 'Disconnected',
        timestamp: new Date() 
    });
});

// Iniciar servidor
app.listen(PORT, async () => {
    console.log(`🚀 Servidor backend corriendo en http://localhost:${PORT}`);
    
    // Verificar conexión a DB al inicio
    console.log('🔌 Verificando conexión a base de datos...');
    const dbConnected = await testConnection();
    if (dbConnected) {
        console.log('✅ Conexión a base de datos establecida.');
    } else {
        console.error('❌ Error: No se pudo conectar a la base de datos. Verifica tu archivo .env');
    }
});

module.exports = app;
