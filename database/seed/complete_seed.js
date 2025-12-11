const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

class CompleteSeeder {
    constructor() {
        this.connection = null;
        this.stats = {
            sistemas_operativos: 0,
            fabricantes: 0,
            protocolos: 0,
            usuarios: 0
        };
    }

    async seedUsers() {
        console.log('\n👤 Sembrando Usuarios...');
        const seedPath = path.join(__dirname, 'users_seed.sql');
        try {
            const sql = fs.readFileSync(seedPath, 'utf8');
            // Split by semicolon in case of multiple statements, though here it's likely one
            const statements = sql.split(';').filter(s => s.trim());
            
            for (const stmt of statements) {
                await this.connection.query(stmt);
            }
            
            const [rows] = await this.connection.execute('SELECT COUNT(*) as count FROM users');
            this.stats.usuarios = rows[0].count;
            console.log(`✅ Usuarios: ${rows[0].count} registros`);
        } catch (error) {
             console.error('❌ Error sembrando usuarios:', error.message);
        }
    }

    async connect() {
        console.log('🔗 Conectando a la base de datos...');
        
        this.connection = await mysql.createConnection({
            host: process.env.DB_HOST || 'localhost',
            port: process.env.DB_PORT || 3306,
            user: process.env.DB_USER || 'root',
            password: process.env.DB_PASSWORD || '',
            database: process.env.DB_NAME || 'network_monitor',
            charset: 'utf8mb4'
        });
        
        console.log('✅ Conexión exitosa');
    }

    async disconnect() {
        if (this.connection) {
            await this.connection.end();
            console.log('🔌 Conexión cerrada');
        }
    }

    async checkTableExists(tableName) {
        const [rows] = await this.connection.execute(
            `SELECT COUNT(*) as count FROM information_schema.tables 
             WHERE table_schema = ? AND table_name = ?`,
            [process.env.DB_NAME || 'network_monitor', tableName]
        );
        return rows[0].count > 0;
    }

    // ==================== SISTEMAS OPERATIVOS ====================
    async seedSistemasOperativos() {
        console.log('\n🌱 Sembrando Sistemas Operativos...');
        
        const sistemasOperativos = [
            // Windows Desktop
            'Windows 11', 'Windows 10', 'Windows 8.1', 'Windows 8', 'Windows 7',
            'Windows Vista', 'Windows XP',
            
            // Windows Server
            'Windows Server 2022', 'Windows Server 2019', 'Windows Server 2016',
            'Windows Server 2012', 'Windows Server 2008', 'Windows Server 2003',
            
            // Linux Desktop/Distros
            'Ubuntu', 'Debian', 'CentOS', 'Red Hat Enterprise Linux', 'Fedora',
            'Arch Linux', 'Linux Mint', 'openSUSE', 'Kali Linux',
            'Raspberry Pi OS', 'Alpine Linux', 'Gentoo',
            
            // Unix/macOS
            'macOS', 'FreeBSD', 'OpenBSD', 'NetBSD', 'TrueNAS',
            
            // Network Devices (genéricos primero)
            'Router', 'Switch', 'Firewall', 'Access Point', 'Network Device',
            'Printer', 'NAS Device', 'VoIP Phone', 'Camera', 'IoT Device',
            
            // Específicos de fabricantes
            'Cisco IOS', 'MikroTik RouterOS', 'Ubiquiti EdgeOS', 'pfSense',
            'OPNsense', 'FortiOS', 'Palo Alto PAN-OS',
            
            // Virtualización
            'VMware ESXi', 'Proxmox VE', 'Hyper-V',
            
            // Mobile
            'Android', 'iOS', 'iPadOS', 'Chrome OS',
            
            // Categorías genéricas para detección básica
            'Windows (Generic)', 'Linux/Unix (Generic)', 'Unknown', 'Desconocido'
        ];
        
        const values = sistemasOperativos.map(nombre => [nombre]);
        
        try {
            await this.connection.query(
                'INSERT IGNORE INTO sistemas_operativos (nombre) VALUES ?', 
                [values]
            );
            
            const [rows] = await this.connection.execute('SELECT COUNT(*) as count FROM sistemas_operativos');
            this.stats.sistemas_operativos = rows[0].count;
            console.log(`✅ Sistemas operativos: ${rows[0].count} registros`);
            
        } catch (error) {
            console.error('❌ Error sembrando sistemas operativos:', error.message);
        }
    }

    // ==================== FABRICANTES OUI (Versión simplificada) ====================
    async seedFabricantes() {
        console.log('\n🏭 Sembrando Fabricantes (OUI)...');
        
        // Lista básica de fabricantes (sin descargar archivos grandes)
        const fabricantesBasicos = [
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
            ['VMware, Inc.', '000C29'],
            ['Amazon Technologies Inc.', '0C47C9'],
            ['Raspberry Pi Trading', 'B827EB'],
            ['Ubiquiti Networks', '002722'],
            ['MikroTik', '4C5E0C']
        ];
        
        try {
            await this.connection.query(
                'INSERT IGNORE INTO fabricantes (nombre, oui_mac) VALUES ?', 
                [fabricantesBasicos]
            );
            
            const [rows] = await this.connection.execute('SELECT COUNT(*) as count FROM fabricantes');
            this.stats.fabricantes = rows[0].count;
            console.log(`✅ Fabricantes: ${rows[0].count} registros`);
            
        } catch (error) {
            console.error('❌ Error sembrando fabricantes:', error.message);
        }
    }

    // ==================== PROTOCOLOS (Versión simplificada) ====================
    async seedProtocolos() {
        console.log('\n🔌 Sembrando Protocolos...');
        
        // Protocolos más comunes (sin descargar CSV gigante)
        const protocolosComunes = [
            // Esenciales
            [53, 'DNS', 'esencial', 'Domain Name System'],
            [67, 'DHCP', 'esencial', 'Dynamic Host Configuration Protocol'],
            [68, 'DHCP', 'esencial', 'Dynamic Host Configuration Protocol'],
            [123, 'NTP', 'esencial', 'Network Time Protocol'],
            [161, 'SNMP', 'esencial', 'Simple Network Management Protocol'],
            [162, 'SNMP-Trap', 'esencial', 'SNMP Trap'],
            
            // Seguros
            [22, 'SSH', 'seguro', 'Secure Shell'],
            [443, 'HTTPS', 'seguro', 'HTTP Secure'],
            [993, 'IMAPS', 'seguro', 'IMAP Secure'],
            [995, 'POP3S', 'seguro', 'POP3 Secure'],
            [465, 'SMTPS', 'seguro', 'SMTP Secure'],
            
            // Correo
            [25, 'SMTP', 'correo', 'Simple Mail Transfer Protocol'],
            [110, 'POP3', 'correo', 'Post Office Protocol v3'],
            [143, 'IMAP', 'correo', 'Internet Message Access Protocol'],
            [587, 'SMTP-Submission', 'correo', 'SMTP Submission'],
            
            // Bases de datos
            [3306, 'MySQL', 'base_de_datos', 'MySQL Database'],
            [5432, 'PostgreSQL', 'base_de_datos', 'PostgreSQL Database'],
            [1433, 'MSSQL', 'base_de_datos', 'Microsoft SQL Server'],
            [27017, 'MongoDB', 'base_de_datos', 'MongoDB Database'],
            [6379, 'Redis', 'base_de_datos', 'Redis Database'],
            
            // Gestión
            [3389, 'RDP', 'remoto', 'Remote Desktop Protocol'],
            [5900, 'VNC', 'remoto', 'Virtual Network Computing'],
            [8080, 'HTTP-Proxy', 'gestion', 'HTTP Proxy'],
            [9090, 'Prometheus', 'gestion', 'Prometheus Monitoring'],
            
            // Inseguros
            [80, 'HTTP', 'inseguro', 'Hypertext Transfer Protocol'],
            [21, 'FTP', 'inseguro', 'File Transfer Protocol'],
            [23, 'Telnet', 'inseguro', 'Telnet Protocol'],
            [135, 'MSRPC', 'inseguro', 'Microsoft RPC'],
            [139, 'NetBIOS', 'inseguro', 'NetBIOS Session Service'],
            [445, 'SMB', 'inseguro', 'Server Message Block'],
            
            // Desarrollo
            [3000, 'Node.js', 'desarrollo', 'Node.js Development'],
            [5000, 'Flask', 'desarrollo', 'Flask Development Server'],
            [8000, 'Django', 'desarrollo', 'Django Development Server'],
            [8081, 'Dev-Server', 'desarrollo', 'Development Server'],
            
            // Inusuales/Juegos
            [25565, 'Minecraft', 'juegos', 'Minecraft Server'],
            [27015, 'Steam', 'juegos', 'Steam Gaming'],
            [6667, 'IRC', 'inusual', 'Internet Relay Chat']
        ];
        
        try {
            await this.connection.query(
                'INSERT IGNORE INTO protocolos (numero, nombre, categoria, descripcion) VALUES ?', 
                [protocolosComunes]
            );
            
            const [rows] = await this.connection.execute('SELECT COUNT(*) as count FROM protocolos');
            this.stats.protocolos = rows[0].count;
            console.log(`✅ Protocolos: ${rows[0].count} registros`);
            
        } catch (error) {
            console.error('❌ Error sembrando protocolos:', error.message);
        }
    }

    // ==================== MÉTODO PRINCIPAL ====================
    async runAll() {
        console.log('='.repeat(60));
        console.log('🌱 SEEDING COMPLETO DE BASE DE DATOS');
        console.log('='.repeat(60));
        
        try {
            await this.connect();
            
            // Verificar que las tablas existan
            const tables = ['sistemas_operativos', 'fabricantes', 'protocolos'];
            for (const table of tables) {
                const exists = await this.checkTableExists(table);
                if (!exists) {
                    console.error(`❌ La tabla '${table}' no existe. Ejecuta primero: npm run db:init`);
                    return;
                }
            }
            
            // Ejecutar todos los seedings
            await this.seedSistemasOperativos();
            await this.seedFabricantes();
            await this.seedProtocolos();
            await this.seedUsers();
            
            // Mostrar resumen
            console.log('\n' + '='.repeat(60));
            console.log('📊 RESUMEN FINAL');
            console.log('='.repeat(60));
            console.log(`✅ Sistemas Operativos: ${this.stats.sistemas_operativos}`);
            console.log(`✅ Fabricantes (OUI): ${this.stats.fabricantes}`);
            console.log(`✅ Protocolos: ${this.stats.protocolos}`);
            console.log(`✅ Usuarios: ${this.stats.usuarios}`);
            console.log('\n✨ SEEDING COMPLETADO EXITOSAMENTE ✨');
            
        } catch (error) {
            console.error('❌ Error en seeding:', error);
        } finally {
            await this.disconnect();
        }
    }

    // ==================== MÉTODO PARA SEMBRAR INDIVIDUALMENTE ====================
    async runSpecific(seedType) {
        try {
            await this.connect();
            
            switch(seedType) {
                case 'so':
                    await this.seedSistemasOperativos();
                    break;
                case 'oui':
                    await this.seedFabricantes();
                    break;
                case 'protocols':
                    await this.seedProtocolos();
                    break;
                default:
                    console.error(`❌ Tipo de seeding desconocido: ${seedType}`);
                    console.log('Opciones válidas: so, oui, protocols');
            }
            
        } catch (error) {
            console.error(`❌ Error en seeding ${seedType}:`, error);
        } finally {
            await this.disconnect();
        }
    }
}

// ==================== EJECUCIÓN ====================
if (require.main === module) {
    const seeder = new CompleteSeeder();
    const command = process.argv[2];
    
    if (command === 'so' || command === 'oui' || command === 'protocols') {
        seeder.runSpecific(command);
    } else {
        seeder.runAll();
    }
}

module.exports = CompleteSeeder;