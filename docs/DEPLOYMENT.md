# Guía de Despliegue y Compilación
## Network Scanner & Monitor Professional

Este documento describe cómo compilar y empaquetar la solución para un entorno de producción (Windows Server / Desktop).

### 1. Requisitos Previos
*   .NET SDK 8.0 o superior (El proyecto actual usa .NET 10.0 Preview según el entorno).
*   Visual Studio 2022 o VS Code.
*   Permisos de Administrador para instalar el servicio.

### 2. Estructura de la Solución
La solución se encuentra en la carpeta `src` y consta de:
*   **NetworkScanner.UI**: Interfaz gráfica de administración (WPF).
*   **NetworkScanner.Service**: Servicio de Windows en segundo plano (Worker).
*   **NetworkScanner.Shared**: Biblioteca de modelos compartidos.

### 3. Compilación para Producción (Publish)

Para generar ejecutables `.exe` independientes (Self-Contained) que no requieran instalar .NET en la máquina cliente, ejecuta los siguientes comandos desde la carpeta raíz del repositorio:

#### A. Publicar el Servicio
```powershell
cd src/NetworkScanner.Service
dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o ../../dist/Service
```

#### B. Publicar la Interfaz (UI)
```powershell
cd ../NetworkScanner.UI
dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o ../../dist/UI
```

### 4. Instalación en el Cliente

1.  Copia todo el contenido de la carpeta `dist/Service` y `dist/UI` a una carpeta en el servidor destino, por ejemplo `C:\Program Files\NetworkScanner`.
    *   *Nota*: Para que la UI gestione el servicio correctamente, se recomienda poner ambos ejecutables en la misma carpeta o asegurarse que la UI pueda encontrar al Servicio.
2.  Asegúrate de que `appsettings.json` esté configurado correctamente con la URL de tu API PHP y la ruta del script PowerShell (`NetworkScanner.ps1`).
    *   Copia la carpeta `agent` con el script `.ps1` a una ubicación accesible (ej. dentro de la carpeta de instalación) y actualiza el `appsettings.json`.
3.  Ejecuta `NetworkScanner.UI.exe` como Administrador.
4.  Haz clic en **Instalar Servicio**.
5.  Haz clic en **Iniciar**.

### 5. Verificación
*   Abre el administrador de tareas -> Servicios y busca "NetworkScannerService".
*   Revisa los logs en `C:\Logs\NetworkScanner`.

### 6. Notas de Seguridad
*   El servicio se instala por defecto con la cuenta `LocalSystem`.
*   El script PowerShell se ejecuta en modo `Bypass` para evitar restricciones de ejecución.
