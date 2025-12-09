const runMigration = require('./scripts/migrate');
const seedOui = require('./seed/seed_oui');
const seedProtocolos = require('./seed/seed_protocolos');

async function init() {
    console.log('========================================');
    console.log('🛠️  INICIALIZACIÓN DE BASE DE DATOS JS');
    console.log('========================================');

    try {
        await runMigration();
        console.log('\n----------------------------------------\n');
        
        await seedOui();
        console.log('\n----------------------------------------\n');
        
        await seedProtocolos();
        console.log('\n----------------------------------------\n');
        
        console.log('✨ TODO COMPLETADO CORRECTAMENTE ✨');
        process.exit(0);
    } catch (error) {
        console.error('❌ Falló la inicialización:', error);
        process.exit(1);
    }
}

init();
