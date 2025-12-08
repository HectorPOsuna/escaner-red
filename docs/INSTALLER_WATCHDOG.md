# Actualización del Instalador - Sistema Watchdog Completo

## Cambios Realizados

### 1. Build Script (`build_installer.ps1`)

✅ **Agregado Paso 4: Compilación del Watchdog**

```powershell
# 4. Compilar y publicar el Watchdog
dotnet publish NetworkScanner.Watchdog -c Release -r win-x64 --self-contained -o dist/Watchdog
```

**Resultado:** El watchdog ahora se compila automáticamente al ejecutar `.\build_installer.ps1`

---

### 2. Inno Setup Script (`installer/setup.iss`)

#### 2.1 Nueva Opción de Instalación

✅ **Checkbox en el Wizard:**
```ini
[Tasks]
Name: "installwatchdog"; 
Description: "Instalar Watchdog (monitoreo externo - recomendado para producción)"; 
GroupDescription: "Watchdog:"; 
Flags: checked
```

**UI del Instalador:**
```
┌─────────────────────────────────────────┐
│ Seleccione componentes adicionales:    │
├─────────────────────────────────────────┤
│ Iconos adicionales:                     │
│   ☑ Crear icono en escritorio          │
│                                         │
│ Servicio Windows:                       │
│   ☑ Iniciar servicio automáticamente   │
│                                         │
│ Watchdog:                               │
│   ☑ Instalar Watchdog (monitoreo       │
│     externo - recomendado para          │
│     producción)                         │
└─────────────────────────────────────────┘
```

#### 2.2 Archivos del Watchdog

✅ **Copia Condicional:**
```ini
[Files]
Source: "..\dist\Watchdog\*"; 
DestDir: "{app}\Watchdog"; 
Flags: ignoreversion recursesubdirs createallsubdirs; 
Tasks: installwatchdog
```

**Solo se copia si el usuario selecciona la opción.**

#### 2.3 Instalación del Servicio Watchdog

✅ **Comandos de Instalación:**
```ini
[Run]
; Crear servicio watchdog
Filename: "sc.exe"; 
Parameters: "create NetworkScannerWatchdog binPath= ""{app}\Watchdog\NetworkScanner.Watchdog.exe"" start= auto"; 
Tasks: installwatchdog

; Configurar descripción
Filename: "sc.exe"; 
Parameters: "description NetworkScannerWatchdog ""Watchdog para Network Scanner Service"""; 
Tasks: installwatchdog

; Iniciar servicio
Filename: "sc.exe"; 
Parameters: "start NetworkScannerWatchdog"; 
Tasks: installwatchdog
```

#### 2.4 Desinstalación del Watchdog

✅ **Limpieza Automática:**
```ini
[UninstallRun]
; Detener watchdog
Filename: "sc.exe"; 
Parameters: "stop NetworkScannerWatchdog"; 
Flags: runhidden

; Eliminar watchdog
Filename: "sc.exe"; 
Parameters: "delete NetworkScannerWatchdog"; 
Flags: runhidden

; Desinstalar servicio principal
Filename: "{app}\Installer\NetworkScanner.Installer.exe"; 
Parameters: "uninstall"
```

---

## Estructura del Instalador Final

```
NetworkScanner_v1.0.0_Setup.exe
├── CAPA 1: Auto-supervisión (incluida en Service)
│   ├── Global exception handlers
│   ├── Exponential backoff
│   ├── Circuit breaker
│   └── Heartbeat monitoring
│
├── CAPA 2: Windows SCM Recovery (configurada automáticamente)
│   ├── Reinicio en 1 min (1er fallo)
│   ├── Reinicio en 2 min (2do fallo)
│   └── Reinicio en 5 min (3er+ fallo)
│
└── CAPA 3: Watchdog Externo (OPCIONAL - checkbox)
    ├── NetworkScanner.Watchdog.exe
    ├── Monitoreo de heartbeat
    └── Reinicio automático si cuelgue
```

---

## Flujo de Instalación

### Usuario Ejecuta el Instalador

1. **Wizard de Bienvenida**
2. **Licencia**
3. **Directorio de Instalación**
4. **Selección de Componentes:**
   - ☑ Crear icono en escritorio
   - ☑ Iniciar servicio automáticamente
   - ☑ **Instalar Watchdog** ← NUEVO

5. **Instalación:**
   ```
   [1/6] Copiando archivos del servicio...
   [2/6] Copiando archivos de la UI...
   [3/6] Copiando archivos del watchdog... (si seleccionado)
   [4/6] Instalando servicio principal...
   [5/6] Configurando recuperación automática (SCM)...
   [6/6] Instalando servicio watchdog... (si seleccionado)
   ```

6. **Finalización:**
   - Opción de abrir UI
   - Servicios corriendo en segundo plano

---

## Verificación Post-Instalación

### Con Watchdog Instalado

```powershell
# Verificar servicio principal
sc query NetworkScannerService

# Verificar watchdog
sc query NetworkScannerWatchdog

# Ver configuración de recuperación
sc qfailure NetworkScannerService

# Ver servicios en services.msc
services.msc
```

**Resultado esperado:**
```
SERVICE_NAME: NetworkScannerService
        STATE              : 4  RUNNING

SERVICE_NAME: NetworkScannerWatchdog
        STATE              : 4  RUNNING
```

### Sin Watchdog (solo CAPAS 1 y 2)

```powershell
# Solo servicio principal
sc query NetworkScannerService

# Watchdog no existe
sc query NetworkScannerWatchdog
# Error: El servicio especificado no existe como servicio instalado.
```

---

## Tamaño del Instalador

| Componente | Tamaño Aproximado |
|------------|-------------------|
| Service (con .NET runtime) | ~60 MB |
| UI (con .NET runtime) | ~50 MB |
| Watchdog (con .NET runtime) | ~60 MB |
| PowerShell Agent | ~1 MB |
| Installer Helper | ~10 MB |
| **Total (con watchdog)** | **~180 MB** |
| **Total (sin watchdog)** | **~120 MB** |

---

## Recomendaciones de Instalación

### Entornos de Desarrollo/Prueba
```
☐ Instalar Watchdog
```
**Razón:** CAPAS 1 y 2 son suficientes para desarrollo.

### Entornos de Producción
```
☑ Instalar Watchdog
```
**Razón:** Máxima disponibilidad con detección de cuelgues.

### Servidores Críticos 24/7
```
☑ Instalar Watchdog
```
**Razón:** Detección de deadlocks y monitoreo funcional.

---

## Desinstalación

El desinstalador automáticamente:
1. ✅ Detiene watchdog (si existe)
2. ✅ Elimina servicio watchdog
3. ✅ Detiene servicio principal
4. ✅ Elimina servicio principal
5. ✅ Borra archivos del programa
6. ✅ Conserva logs (opcional)

---

## Próximos Pasos

### Generar Instalador Actualizado

```powershell
# Compilar todo y generar instalador
.\build_installer.ps1

# Resultado
dist\NetworkScanner_v1.0.0_Setup.exe
```

### Probar Instalación

```powershell
# Ejecutar instalador
dist\NetworkScanner_v1.0.0_Setup.exe

# Durante instalación:
# - Seleccionar "Instalar Watchdog"
# - Completar wizard

# Verificar
sc query NetworkScannerService
sc query NetworkScannerWatchdog
```

---

## Resumen

✅ **CAPA 1** - Incluida automáticamente en Service
✅ **CAPA 2** - Configurada automáticamente por Installer
✅ **CAPA 3** - Opcional, seleccionable durante instalación
✅ **Build Script** - Compila watchdog automáticamente
✅ **Inno Setup** - Instala watchdog si usuario lo selecciona
✅ **Desinstalador** - Limpia watchdog automáticamente

**El instalador ahora incluye TODO el sistema watchdog de 3 capas.**
