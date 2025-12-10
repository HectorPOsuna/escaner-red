# Plan de Testing End-to-End (E2E) - NetworkScanner

## 🎯 Objetivo
Asegurar la robustez, estabilidad y preparación para producción del sistema NetworkScanner mediante un conjunto de pruebas exhaustivas y automáticas.

## ✅ Checklist de Pruebas E2E

### 1️⃣ Instalador (.exe)
- [ ] **Instalación Limpia**: Instalar en VM limpia (Windows 10/11) sin dependencias previas.
- [ ] **Verificación de Archivos**: Confirmar presencia de:
  - `C:\Program Files\NetworkScanner\Service\NetworkScanner.Service.exe`
  - `C:\Program Files\NetworkScanner\Agent\NetworkScanner.ps1`
  - `C:\Program Files\NetworkScanner\UI\NetworkScanner.UI.exe`
- [ ] **Registro de Servicio**: Verificar `sc query NetworkScannerService` (Estado: STOPPED o RUNNING).
- [ ] **Permisos**: Verificar que `C:\ProgramData\NetworkScanner\Logs` es escribible por `Users`.
- [ ] **Desinstalación**: Confirmar eliminación limpia de archivos y servicio.

### 2️⃣ Servicio de Windows
- [ ] **Auto-Arranque**: Reiniciar VM y verificar que el servicio inicia sin login de usuario.
- [ ] **Ejecución de Ciclo**: Verificar logs en `ProgramData` para confirmar ejecución periódica del agente.
- [ ] **Recuperación**: Matar proceso `NetworkScanner.Service.exe` desde Task Manager y verificar auto-reinicio (Recovery Actions).
- [ ] **Offline**: Desconectar cable de red y verificar comportamiento (no debe crashear, debe loguear error de conexión).

### 3️⃣ Agente PowerShell
- [ ] **Escaneo Básico**: Ejecutar `NetworkScanner.ps1` manualmente y verificar salida JSON.
- [ ] **Subred Inválida**: Configurar `config.ps1` con prefijo inválido (e.g., `999.999.`) y validar manejo de error.
- [ ] **Timeout**: Simular latencia alta y verificar que no cuelga indefinidamente.
- [ ] **Métricas**: Validar que el objeto de métricas (CPU/RAM) se genera correctamente.

### 4️⃣ UI WPF & System Tray
- [ ] **Start Minimized**: Verificar que la app inicia en bandeja sin mostrar ventana.
- [ ] **Interacción**: Clic derecho en icono -> "Abrir" despliega ventana.
- [ ] **Estado**: Verificar que los indicadores visuales (LEDs) reflejan el estado real del servicio.
- [ ] **Configuración**: Cambiar configuración desde UI y verificar persistencia en `config.ps1` o JSON.

### 5️⃣ API & Persistencia
- [ ] **Payload Masivo**: Enviar JSON con 500 dispositivos simulados para test de carga.
- [ ] **SQL Injection**: Intentar inyectar SQL en campos `Hostname` y `MAC`.
- [ ] **Conflictos**:
  1. Enviar Host A (IP: 1.1.1.1, MAC: AA:AA...).
  2. Enviar Host B (IP: 1.1.1.1, MAC: BB:BB...).
  3. Verificar tabla `conflictos` en BD.
- [ ] **Reintentos**: Simular error 500 en API por 3 intentos y luego éxito, verificar lógica de reintento del agente.

## ⚠️ Análisis de Riesgos y Recomendaciones

### Riesgos Detectados
1. **Configuración de Seguridad en PHP**: `ini_set('display_errors', 0)` es bueno, pero logs en un simple archivo de texto pueden crecer indefinidamente sin rotación.
2. **Watchdog del Servicio**: El código del servicio (Worker.cs) parece ser un loop simple con `Task.Delay`. Si el proceso hijo (PowerShell) se cuelga, el servicio podría quedar "zombie".
3. **Validación de Input**: `receive.php` valida estructura pero no sanitiza profundamente strings antes de insertarlos (aunque PDO ayuda, es mejor limpiar caracteres XSS/Control).

### Recomendaciones de Hardening (Senior Engineer)
1. **Implementar Log Rotation**: En el agente y en la API para evitar llenar el disco.
2. **Timeout Agresivo en Servicio**: Usar `WaitForExit(timeout)` al invocar PowerShell para matar procesos colgados.
3. **Mutual TLS (mTLS)**: Para producción real, asegurar que solo agentes con certificado válido puedan hablar con la API.
4. **Health Check Endpoint**: Crear `api/health.php` para monitoreo externo del estado del servidor.

## 📊 Métricas para Producción
- **Success Rate**: % de escaneos exitosos vs fallidos (Alerta si < 95%).
- **Scan Duration**: Tiempo promedio de escaneo (Alerta si > 5 min).
- **Conflict Rate**: Número de conflictos detectados por hora.

## 🔄 Estrategia de Retry (Backoff)
El agente debe implementar **Exponential Backoff** para no saturar la API caída:
- Intento 1: Inmediato
- Intento 2: +2s
- Intento 3: +4s
- Intento 4: +8s
- Fallo final: Log local y esperar siguiente ciclo programado.

---
**Siguientes Pasos**: Ejecutar los scripts de prueba automática adjuntos para validar estado actual.
