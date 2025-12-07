using System;
using System.Diagnostics;
using System.ServiceProcess;
using System.IO;

namespace NetworkScanner.UI
{
    public class ServiceManager
    {
        private const string SERVICE_NAME = "NetworkScannerService";
        private const string DISPLAY_NAME = "Network Scanner & Monitor";
        private const string DESCRIPTION = "Servicio de monitoreo de red y detección de conflictos.";

        public static bool IsInstalled()
        {
            using (var controller = new ServiceController(SERVICE_NAME))
            {
                try
                {
                    var status = controller.Status;
                    return true;
                }
                catch
                {
                    return false;
                }
            }
        }

        public static string GetStatus()
        {
            if (!IsInstalled()) return "No Instalado";

            using (var controller = new ServiceController(SERVICE_NAME))
            {
                try
                {
                    controller.Refresh();
                    return controller.Status.ToString();
                }
                catch
                {
                    return "Error";
                }
            }
        }

        public static void InstallService(string binPath)
        {
            // Usar sc.exe para crear el servicio
            // binPath debe ser el path absoluto al .exe del servicio
            string cmd = $"create \"{SERVICE_NAME}\" binPath= \"{binPath}\" start= auto DisplayName= \"{DISPLAY_NAME}\"";
            RunScCommand(cmd);
            
            // Set description
            RunScCommand($"description \"{SERVICE_NAME}\" \"{DESCRIPTION}\"");
        }

        public static void UninstallService()
        {
            RunScCommand($"delete \"{SERVICE_NAME}\"");
        }

        public static void StartService()
        {
            using (var controller = new ServiceController(SERVICE_NAME))
            {
                if (controller.Status != ServiceControllerStatus.Running)
                {
                    controller.Start();
                    controller.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(10));
                }
            }
        }

        public static void StopService()
        {
            using (var controller = new ServiceController(SERVICE_NAME))
            {
                if (controller.Status == ServiceControllerStatus.Running)
                {
                    controller.Stop();
                    controller.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(10));
                }
            }
        }

        private static void RunScCommand(string arguments)
        {
            var psi = new ProcessStartInfo
            {
                FileName = "sc.exe",
                Arguments = arguments,
                UseShellExecute = true,
                CreateNoWindow = true,
                Verb = "runas" // Admin
            };

            var proc = Process.Start(psi);
            proc.WaitForExit();
        }
    }
}
