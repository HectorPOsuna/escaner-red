# Integración del Servicio con el Agente de Escaneo

## ✅ Integración Completada

El servicio de Windows ahora ejecuta automáticamente el agente PowerShell (`NetworkScanner.ps1`) cada 5 minutos.

## 🔧 Configuración

### Intervalo de Ejecución

Edita en `ScannerWorker.cs`:
```csharp
private const int INTERVALO_EJECUCION_MS = 300000; // 5 minutos
```

O usa `appsettings.json`:
```json
{
  "ScannerSettings": {
    "IntervalMinutes": 5
  }
}
```

### Ruta del Script

Por defecto, el servicio busca el script en:
```
[DirectorioDelServicio]\..\agent\NetworkScanner.ps1
```

Si necesitas cambiar la ruta, edita en `ScannerWorker.cs`:
```csharp
string scriptPath = Path.Combine(
    AppDomain.CurrentDomain.BaseDirectory,
    @"..\agent\NetworkScanner.ps1"  // <-- Cambiar aquí
);
```

## 📊 Logs del Servicio

### Ubicación
```
C:\Logs\MiServicio\service_YYYYMMDD.log
```

### Formato de Logs

```
[2025-12-04 17:30:00] === INICIO DE EJECUCIÓN DEL AGENTE ===
[2025-12-04 17:30:00] Ejecutando script: D:\GITHUB\escaner-red\agent\NetworkScanner.ps1
[2025-12-04 17:30:00] Iniciando proceso PowerShell...
[2025-12-04 17:30:01] [PS] ================================================================
[2025-12-04 17:30:01] [PS]    INICIANDO ESCÁNER DE RED - MONITOR DE PROTOCOLOS
[2025-12-04 17:30:01] [PS] ================================================================
[2025-12-04 17:30:01] [PS] Subred objetivo: 192.168.1.0/24
[2025-12-04 17:30:01] [PS] Modo de operación: hybrid
...
[2025-12-04 17:35:00] Script finalizado. Código de salida: 0
[2025-12-04 17:35:00] ✅ Escaneo completado exitosamente
[2025-12-04 17:35:00] === FIN DE EJECUCIÓN DEL AGENTE ===
```

## 🛡️ Manejo de Errores

### Timeout
- **Límite**: 10 minutos por ejecución
- **Acción**: Si el script excede el tiempo, el proceso se termina automáticamente
- **Log**: Se registra advertencia en el log

### Script No Encontrado
```
[2025-12-04 17:30:00] ERROR: No se encontró el script en: [ruta]
```
**Solución**: Verifica que `NetworkScanner.ps1` existe en la ruta especificada

### Errores de PowerShell
Todos los errores de PowerShell se capturan y registran con prefijo `[PS ERROR]`

### Códigos de Salida
- **0**: Éxito
- **Otro**: Error (se registra advertencia)

## 🚀 Instalación y Uso

### 1. Compilar el Servicio
```powershell
cd agent-service
dotnet build -c Release
```

### 2. Instalar el Servicio
```powershell
# Como Administrador
.\install-service.ps1 -Action install
```

### 3. Verificar Ejecución
```powershell
# Ver logs en tiempo real
Get-Content C:\Logs\MiServicio\service_*.log -Wait

# Ver estado del servicio
Get-Service NetworkScannerService
```

## 🔍 Troubleshooting

### El servicio no ejecuta el script

**Verificar:**
1. Ruta del script es correcta
2. PowerShell está en el PATH del sistema
3. El servicio tiene permisos de ejecución
4. Revisar logs en `C:\Logs\MiServicio\`

**Solución:**
```powershell
# Ver logs del servicio
Get-Content C:\Logs\MiServicio\service_*.log -Tail 50
```

### Error: "Execution Policy"

El servicio usa `-ExecutionPolicy Bypass`, pero si aún falla:

```powershell
# Como Administrador
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### El script se ejecuta pero no procesa datos

**Verificar:**
1. El archivo `config.ps1` existe en `agent/`
2. La configuración de API/modo está correcta
3. PHP está instalado y en el PATH (para modo local)
4. La API está accesible (para modo API)

**Revisar logs del scanner:**
```powershell
# Los logs del PowerShell aparecen en el log del servicio con prefijo [PS]
Get-Content C:\Logs\MiServicio\service_*.log | Select-String "\[PS\]"
```

## 📈 Monitoreo

### Ver Ejecuciones Recientes
```powershell
Get-Content C:\Logs\MiServicio\service_*.log | Select-String "INICIO DE EJECUCIÓN"
```

### Contar Ejecuciones Exitosas
```powershell
(Get-Content C:\Logs\MiServicio\service_*.log | Select-String "Escaneo completado exitosamente").Count
```

### Ver Errores
```powershell
Get-Content C:\Logs\MiServicio\service_*.log | Select-String "ERROR"
```

## 🔄 Flujo Completo

1. **Servicio inicia** → Timer configurado (5 min)
2. **Timer dispara** → `EjecutarAgente()` se ejecuta
3. **Ejecuta PowerShell** → `NetworkScanner.ps1`
4. **Scanner escanea red** → Detecta dispositivos
5. **Procesa datos**:
   - **Modo API**: Envía a `server/api/receive.php`
   - **Modo Local**: Ejecuta `server/cron_process.php`
   - **Modo Hybrid**: Intenta API, si falla → Local
6. **Logs capturados** → Se guardan en `C:\Logs\MiServicio\`
7. **Espera 5 minutos** → Repite

## 💡 Optimizaciones

### Reducir Logs
Si los logs son muy verbosos, edita `ScannerWorker.cs`:
```csharp
// Comentar esta línea para no registrar cada línea de PowerShell
// EscribirLog($"[PS] {e.Data}");
```

### Cambiar Timeout
```csharp
bool finished = process.WaitForExit(600000); // 10 minutos
// Cambiar a: process.WaitForExit(300000); // 5 minutos
```

### Ejecutar Inmediatamente al Iniciar
En `ExecuteAsync`, ya está configurado para ejecutar inmediatamente:
```csharp
// Ejecutar inmediatamente al iniciar (opcional)
EjecutarAgente();
```

Para desactivar, comenta esa línea.
