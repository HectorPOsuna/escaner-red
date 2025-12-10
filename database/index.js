const CompleteSeeder = require('./seed/complete_seed');

async function init() {
    console.log('='.repeat(50));
    console.log('🛠️  INICIALIZACIÓN COMPLETA DE BASE DE DATOS');
    console.log('='.repeat(50));
    
    try {
        const seeder = new CompleteSeeder();
        await seeder.runAll();
        
        console.log('\n✨ INICIALIZACIÓN COMPLETADA ✨');
        process.exit(0);
        
    } catch (error) {
        console.error('❌ Falló la inicialización:', error);
        process.exit(1);
    }
}

// Ejecutar si se llama directamente
if (require.main === module) {
    init();
}