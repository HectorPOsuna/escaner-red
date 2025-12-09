require('dotenv').config({ path: '../.env' });
const mysql = require('mysql2/promise');

const config = {
    host: process.env.DB_HOST || '127.0.0.1',
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    multipleStatements: true // Important for running SQL scripts
};

// Connect without DB first to create it if needed, or connect with DB if it exists.
// For initialization, we usually connect without DB to CREATE DATABASE.
const createConnection = async (withDb = false) => {
    const dbConfig = { ...config };
    if (withDb) {
        dbConfig.database = process.env.DB_NAME || 'red_monitor';
    }
    return await mysql.createConnection(dbConfig);
};

module.exports = { createConnection, dbName: process.env.DB_NAME || 'red_monitor' };
