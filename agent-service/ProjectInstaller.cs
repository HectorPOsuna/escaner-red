using System.ComponentModel;
using System.Configuration.Install;
using System.ServiceProcess;

namespace NetworkScannerService
{
    /// <summary>
    /// Instalador del servicio de Windows
    /// Permite instalar/desinstalar el servicio usando InstallUtil.exe
    /// </summary>
    [RunInstaller(true)]
    public class ProjectInstaller : Installer
    {
        private ServiceProcessInstaller serviceProcessInstaller;
        private ServiceInstaller serviceInstaller;

        public ProjectInstaller()
        {
            // Configurar el instalador del proceso del servicio
            serviceProcessInstaller = new ServiceProcessInstaller
            {
                // Ejecutar como LocalSystem (máximos privilegios)
                // Otras opciones: LocalService, NetworkService, User
                Account = ServiceAccount.LocalSystem
            };

            // Configurar el instalador del servicio
            serviceInstaller = new ServiceInstaller
            {
                // Nombre interno del servicio (usado en comandos sc)
                ServiceName = "NetworkScannerService",
                
                // Nombre visible en el panel de servicios
                DisplayName = "Network Scanner Service",
                
                // Descripción del servicio
                Description = "Servicio que ejecuta escaneos de red periódicos y envía datos a la API central",
                
                // Tipo de inicio: Automatic, Manual, Disabled
                StartType = ServiceStartMode.Automatic,
                
                // Acción si el servicio falla
                // DelayedAutoStart = true // Opcional: iniciar después de otros servicios
            };

            // Agregar los instaladores a la colección
            Installers.Add(serviceProcessInstaller);
            Installers.Add(serviceInstaller);
        }
    }
}
