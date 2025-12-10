const mysql = require('mysql2/promise');

async function seedSistemasOperativos() {
    console.log('🌱 Sembrando Sistemas Operativos...');
    
    const connection = await mysql.createConnection({
        host: 'localhost',
        user: 'root', // Cambia según tu configuración
        password: 'tu_password',
        database: 'tu_base_de_datos'
    });
    
    try {
        // Verificar si ya hay datos
        const [rows] = await connection.execute('SELECT COUNT(*) as count FROM sistemas_operativos');
        if (rows[0].count > 0) {
            console.log(`✅ Ya existen ${rows[0].count} sistemas operativos.`);
            
            // Mostrar lo que hay
            const [existing] = await connection.execute('SELECT * FROM sistemas_operativos LIMIT 10');
            console.log('\n🔢 Muestra existente:');
            existing.forEach(so => console.log(`  • ${so.id_so}: ${so.nombre}`));
            
            await connection.end();
            return;
        }
        
        // Lista optimizada para detección automática
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
        
        // Preparar datos para inserción
        const values = sistemasOperativos.map(nombre => [nombre]);
        
        console.log(`📦 Insertando ${sistemasOperativos.length} sistemas operativos...`);
        
        // Insertar en lote
        await connection.query(
            'INSERT INTO sistemas_operativos (nombre) VALUES ?', 
            [values]
        );
        
        // Verificar inserción
        const [finalRows] = await connection.execute('SELECT COUNT(*) as count FROM sistemas_operativos');
        console.log(`✅ Insertados ${finalRows[0].count} sistemas operativos.`);
        
        // Mostrar con IDs
        const [allOS] = await connection.execute('SELECT id_so, nombre FROM sistemas_operativos ORDER BY id_so');
        console.log('\n📋 Lista completa con IDs:');
        allOS.forEach(so => console.log(`  ${so.id_so.toString().padEnd(3)} - ${so.nombre}`));
        
    } catch (error) {
        console.error('❌ Error sembrando sistemas operativos:', error);
        throw error;
    } finally {
        await connection.end();
    }
}

// Ejecutar si se llama directamente
if (require.main === module) {
    seedSistemasOperativos().catch(console.error);
}

module.exports = seedSistemasOperativos;