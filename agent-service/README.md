# Servicio de Windows - Network Scanner Service

## 📋 Descripción

Servicio de Windows en .NET 8 que ejecuta el agente de escaneo de red de forma automática y periódica.

## 🏗️ Estructura del Proyecto

```
agent-service/
├── NetworkScannerService.csproj  # Configuración del proyecto
├── Program.cs                     # Punto de entrada
├── ScannerWorker.cs              # Lógica del servicio (timer + agente)
└── ProjectInstaller.cs           # Instalador del servicio
```

## ⚙️ Configuración

### Intervalo de Ejecución

Por defecto: **5 minutos** (300,000 ms)

Para cambiar el intervalo, edita en `ScannerWorker.cs`:

```csharp
private const int INTERVALO_EJECUCION_MS = 300000; // 5 minutos
```

### Directorio de Logs

Por defecto: `C:\Logs\MiServicio\`

Los logs se guardan con formato: `service_YYYYMMDD.log`

## 🔨 Compilación

### Opción 1: Visual Studio
1. Abrir `NetworkScannerService.csproj` en Visual Studio
2. Build → Build Solution (Ctrl+Shift+B)
3. El ejecutable estará en: `bin\Release\net8.0-windows\win-x64\`

### Opción 2: Línea de Comandos

```powershell
cd agent-service
dotnet build -c Release
```

O para publicar una versión standalone:

```powershell
dotnet publish -c Release -r win-x64 --self-contained false
```

## 📦 Instalación del Servicio

### Método 1: Usando `sc` (Recomendado)

**Instalar:**
```powershell
# Ejecutar como Administrador
sc create NetworkScannerService binPath= "D:\GITHUB\escaner-red\agent-service\bin\Release\net8.0-windows\NetworkScannerService.exe" start= auto DisplayName= "Network Scanner Service"
```

**Iniciar:**
```powershell
sc start NetworkScannerService
```

**Detener:**
```powershell
sc stop NetworkScannerService
```

**Desinstalar:**
```powershell
sc delete NetworkScannerService
```

### Método 2: Usando `InstallUtil` (Alternativo)

**Instalar:**
```powershell
# Ejecutar como Administrador
# Ruta de InstallUtil en .NET Framework (para compatibilidad)
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe "D:\GITHUB\escaner-red\agent-service\bin\Release\net8.0-windows\NetworkScannerService.exe"
```

**Desinstalar:**
```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\InstallUtil.exe /u "D:\GITHUB\escaner-red\agent-service\bin\Release\net8.0-windows\NetworkScannerService.exe"
```

> **Nota:** Para .NET 8, se recomienda usar `sc` ya que `InstallUtil` es de .NET Framework.

### Método 3: PowerShell (Más Control)

```powershell
# Crear servicio
New-Service -Name "NetworkScannerService" `
    -BinaryPathName "D:\GITHUB\escaner-red\agent-service\bin\Release\net8.0-windows\NetworkScannerService.exe" `
    -DisplayName "Network Scanner Service" `
    -Description "Servicio que ejecuta escaneos de red periódicos" `
    -StartupType Automatic

# Iniciar servicio
Start-Service -Name "NetworkScannerService"

# Ver estado
Get-Service -Name "NetworkScannerService"

# Detener servicio
Stop-Service -Name "NetworkScannerService"

# Eliminar servicio
Remove-Service -Name "NetworkScannerService"
```

## 🔍 Verificación

### Ver el servicio en el Panel de Servicios

1. Presiona `Win + R`
2. Escribe `services.msc`
3. Busca "Network Scanner Service"

### Ver logs

```powershell
Get-Content C:\Logs\MiServicio\service_*.log -Tail 50
```

O en tiempo real:

```powershell
Get-Content C:\Logs\MiServicio\service_*.log -Wait
```

## 🐛 Troubleshooting

### Error: "El servicio no responde"

**Solución:**
- Verifica que el ejecutable tenga permisos de ejecución
- Revisa los logs en `C:\Logs\MiServicio\`
- Verifica que .NET 8 Runtime esté instalado

### Error: "Acceso denegado"

**Solución:**
- Ejecuta PowerShell/CMD como Administrador
- Verifica que la cuenta del servicio tenga permisos

### El servicio no inicia automáticamente

**Solución:**
```powershell
sc config NetworkScannerService start= auto
```

### Ver eventos del servicio

```powershell
Get-EventLog -LogName Application -Source NetworkScannerService -Newest 20
```

## 🔧 Personalización

### Cambiar la cuenta del servicio

Edita en `ProjectInstaller.cs`:

```csharp
Account = ServiceAccount.LocalService  // Menos privilegios
// O
Account = ServiceAccount.NetworkService  // Para acceso a red
```

### Ejecutar código al iniciar

En `ScannerWorker.cs`, el método `ExecuteAsync` se ejecuta al iniciar el servicio.

### Ejecutar código al detener

En `ScannerWorker.cs`, el método `StopAsync` se ejecuta al detener el servicio.

## 📝 Ejemplo de Logs

```
[2025-12-04 17:30:00] Servicio iniciado correctamente
[2025-12-04 17:30:00] Timer configurado con intervalo de 300 segundos
[2025-12-04 17:30:00] === INICIO DE EJECUCIÓN DEL AGENTE ===
[2025-12-04 17:30:00] Simulando escaneo de red...
[2025-12-04 17:30:02] Escaneo completado exitosamente
[2025-12-04 17:30:02] === FIN DE EJECUCIÓN DEL AGENTE ===
[2025-12-04 17:35:00] === INICIO DE EJECUCIÓN DEL AGENTE ===
...
```

## 🚀 Próximos Pasos

1. **Compilar el servicio**
2. **Instalar usando `sc create`**
3. **Verificar en `services.msc`**
4. **Revisar logs en `C:\Logs\MiServicio\`**
5. **Implementar la lógica real en `EjecutarAgente()`**

## 💡 Integración con el Scanner

Para integrar con el scanner PowerShell existente, modifica `EjecutarAgente()`:

```csharp
private void EjecutarAgente()
{
    try
    {
        // Ejecutar NetworkScanner.ps1
        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = @"-File D:\GITHUB\escaner-red\agent\NetworkScanner.ps1",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            CreateNoWindow = true
        };

        using (var process = Process.Start(psi))
        {
            process.WaitForExit();
            EscribirLog($"Scanner ejecutado. Código de salida: {process.ExitCode}");
        }
    }
    catch (Exception ex)
    {
        EscribirLog($"Error ejecutando scanner: {ex.Message}");
    }
}
```
