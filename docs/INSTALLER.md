# Guía de Construcción del Instalador

## Requisitos Previos

### 1. Inno Setup
Descarga e instala Inno Setup 6:
- URL: https://jrsoftware.org/isdl.php
- Versión recomendada: 6.2.2 o superior
- Instalación por defecto: `C:\Program Files (x86)\Inno Setup 6\`

### 2. .NET SDK
- .NET 8.0 SDK o superior
- Verificar: `dotnet --version`

### 3. PowerShell
- PowerShell 5.1 o superior (incluido en Windows 10+)

---

## Proceso de Construcción

### Opción 1: Script Automatizado (Recomendado)

```powershell
# Desde la raíz del proyecto
.\build_installer.ps1
```

Esto generará:
- `dist/NetworkScanner_v1.0.0_Setup.exe`

### Opción 2: Con Versión Personalizada

```powershell
.\build_installer.ps1 -Version "1.2.3"
```

### Opción 3: Manual

```powershell
# 1. Compilar servicio
dotnet publish src/NetworkScanner.Service/NetworkScanner.Service.csproj -c Release -r win-x64 --self-contained -o dist/Service

# 2. Compilar UI
dotnet publish src/NetworkScanner.UI/NetworkScanner.UI.csproj -c Release -r win-x64 --self-contained -o dist/UI

# 3. Compilar Installer
dotnet publish src/NetworkScanner.Installer/NetworkScanner.Installer.csproj -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o dist/Installer

# 4. Generar instalador
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\setup.iss
```

---

## Estructura del Instalador

El instalador generado incluye:

```
NetworkScanner_v1.0.0_Setup.exe
├── Service/
│   ├── NetworkScanner.Service.exe (Servicio Windows)
│   ├── appsettings.json
│   └── [Runtime .NET]
├── UI/
│   ├── NetworkScanner.UI.exe (Interfaz WPF)
│   └── [Runtime .NET]
├── Agent/
│   └── NetworkScanner.ps1 (Script de escaneo)
└── Installer/
    └── NetworkScanner.Installer.exe (Helper de instalación)
```

---

## Proceso de Instalación (Usuario Final)

1. Ejecutar `NetworkScanner_v1.0.0_Setup.exe`
2. Aceptar UAC (permisos de administrador)
3. Seguir wizard de instalación
4. El instalador automáticamente:
   - Copia archivos a `C:\Program Files\NetworkScanner\`
   - Instala el servicio Windows
   - Inicia el servicio
   - Crea acceso directo en escritorio
   - Abre la UI

---

## Desinstalación

### Desde Panel de Control
1. Panel de Control → Programas → Desinstalar un programa
2. Seleccionar "Network Scanner & Monitor"
3. Click en Desinstalar

### Desde Configuración de Windows
1. Configuración → Aplicaciones
2. Buscar "Network Scanner"
3. Click en Desinstalar

El desinstalador automáticamente:
- Detiene el servicio
- Desinstala el servicio
- Elimina archivos del programa
- Conserva logs (opcional)

---

## Instalación Silenciosa (Empresas)

```powershell
# Instalación completamente silenciosa
NetworkScanner_v1.0.0_Setup.exe /VERYSILENT /SUPPRESSMSGBOXES

# Instalación silenciosa con log
NetworkScanner_v1.0.0_Setup.exe /VERYSILENT /LOG="C:\Temp\install.log"

# Desinstalación silenciosa
"C:\Program Files\NetworkScanner\unins000.exe" /VERYSILENT
```

---

## Firma Digital (Producción)

Para firmar el instalador:

```powershell
# Requiere certificado de firma de código
signtool sign /f "certificado.pfx" /p "password" /t http://timestamp.digicert.com dist/NetworkScanner_v1.0.0_Setup.exe
```

---

## Troubleshooting

### Error: "Inno Setup no encontrado"
- Verificar instalación en `C:\Program Files (x86)\Inno Setup 6\`
- O editar `build_installer.ps1` con la ruta correcta

### Error: "dotnet no reconocido"
- Instalar .NET SDK desde https://dotnet.microsoft.com/download

### Error: "Servicio no se instala"
- Verificar permisos de administrador
- Revisar logs en `C:\Logs\NetworkScanner\`

### Error de compilación
```powershell
# Limpiar y reconstruir
dotnet clean src/NetworkScanner.sln
dotnet build src/NetworkScanner.sln -c Release
```

---

## Versionado

Actualizar versión en:
1. `installer/setup.iss` → `#define MyAppVersion`
2. `build_installer.ps1` → parámetro `-Version`
3. Proyectos `.csproj` → `<Version>1.0.0</Version>`

---

## Distribución

El archivo `NetworkScanner_v1.0.0_Setup.exe` es completamente portable:
- Tamaño aproximado: 80-120 MB (incluye runtime .NET)
- No requiere instalaciones previas
- Compatible con Windows 10/11 (64-bit)
