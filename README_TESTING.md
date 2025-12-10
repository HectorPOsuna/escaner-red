# Guía de Testing para NetworkScanner

Esta guía detalla cómo ejecutar las pruebas unitarias automáticas y las pruebas manuales de integración requeridas para validar el sistema.

## 1. Pruebas Automáticas (Unit Testing)

Hemos implementado un set de pruebas para validar la lógica interna del Agente PowerShell (`NetworkScanner.ps1`).

**Requisitos:**
- PowerShell 5.1 o superior
- Módulo Pester (incluido en Win 10/11)

**Instrucciones:**
1. Abrir PowerShell como Administrador.
2. Navegar a la raíz del proyecto.
3. Ejecutar:
   ```powershell
   Invoke-Pester -Path tests\test_agent_functions.ps1
   ```

**Qué se prueba:**
- Carga correcta del script sin errores de sintaxis.
- Exportación de funciones clave (`Get-IpRange`, `Test-HostAlive`).
- Generación correcta de rangos IP.
- Lógica de rotación de logs (prevención de llenado de disco).

## 2. Pruebas de Integración Manuales (E2E Checklist)

Siga este checklist para validar el sistema completo en un entorno de QA/Producción.

### A. Instalación
- [ ] Ejecutar `NetworkScanner_Setup.exe`.
- [ ] Verificar que se crean las carpetas en `C:\Program Files\NetworkScanner`.
- [ ] Verificar que existe el servicio `NetworkScannerService` en `services.msc`.

### B. Servicio Windows
- [ ] Reiniciar la máquina.
- [ ] Verificar que el servicio arranca automáticamente.
- [ ] Revisar `C:\ProgramData\NetworkScanner\Logs\service_YYYYMMDD.log` para confirmar inicio.

### C. Agente y Red
- [ ] Verificar que el agente genera `scan_results.json` en su carpeta.
- [ ] Confirmar que detecta la IP del propio equipo (Localhost) como "Active".
- [ ] Desconectar red y verificar que el log registra "Error de conexión" sin crashear.

### D. API y Backend
- [ ] Verificar logs en `database/logs/api_requests.log` (o ruta configurada).
- [ ] Confirmar que los datos llegan a la Base de Datos (Tabla `equipos`).
- [ ] **Prueba de Conflicto**: Cambiar manualmente la MAC de un equipo en la BD y volver a escanear para ver si detecta el conflicto.

## 3. Escenarios Adversos (Resiliencia)

Para validar la robustez (Hardening):
1. **Matar Proceso**: Abra el Administrador de Tareas y finalice `powershell.exe` mientras escanea. El Servicio debería detectar el error y reintentar en el siguiente ciclo.
2. **API Down**: Detenga su servidor web (IIS/Apache). El agente debe guardar logs locales y reintentar con "Exponential Backoff".
3. **Log Flood**: Verifique que los archivos `.log` en `ProgramData` rotan al llegar a 5MB.
