using System.Diagnostics;
using System.ServiceProcess;

namespace NetworkScanner.Installer;

class Program
{
    private const string ServiceName = "NetworkScannerService";
    private const string ServiceDisplayName = "Network Scanner & Monitor Service";
    private const string ServiceDescription = "Automated network scanning and monitoring service";

    static int Main(string[] args)
    {
        if (args.Length == 0)
        {
            ShowUsage();
            return 1;
        }

        try
        {
            // Verificar permisos de administrador
            if (!IsAdministrator())
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("ERROR: Este programa requiere permisos de administrador.");
                Console.ResetColor();
                return 1;
            }

            string command = args[0].ToLower();

            switch (command)
            {
                case "install":
                    return InstallService(args);
                case "uninstall":
                    return UninstallService();
                case "status":
                    return ShowStatus();
                default:
                    Console.WriteLine($"Comando desconocido: {command}");
                    ShowUsage();
                    return 1;
            }
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"ERROR: {ex.Message}");
            Console.ResetColor();
            return 1;
        }
    }

    static void ShowUsage()
    {
        Console.WriteLine("NetworkScanner.Installer - Utilidad de instalación de servicio");
        Console.WriteLine();
        Console.WriteLine("Uso:");
        Console.WriteLine("  NetworkScanner.Installer.exe install <ruta-al-exe>");
        Console.WriteLine("  NetworkScanner.Installer.exe uninstall");
        Console.WriteLine("  NetworkScanner.Installer.exe status");
        Console.WriteLine();
        Console.WriteLine("Ejemplos:");
        Console.WriteLine("  NetworkScanner.Installer.exe install \"C:\\Program Files\\NetworkScanner\\Service\\NetworkScanner.Service.exe\"");
        Console.WriteLine("  NetworkScanner.Installer.exe uninstall");
    }

    static bool IsAdministrator()
    {
        var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
        var principal = new System.Security.Principal.WindowsPrincipal(identity);
        return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
    }

    static int InstallService(string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("ERROR: Debe especificar la ruta al ejecutable del servicio.");
            ShowUsage();
            return 1;
        }

        string serviceExePath = args[1];

        if (!File.Exists(serviceExePath))
        {
            Console.WriteLine($"ERROR: El archivo no existe: {serviceExePath}");
            return 1;
        }

        Console.WriteLine($"Instalando servicio '{ServiceDisplayName}'...");

        // Verificar si el servicio ya existe
        if (ServiceExists(ServiceName))
        {
            Console.WriteLine("El servicio ya está instalado. Desinstalando versión anterior...");
            UninstallService();
            Thread.Sleep(2000); // Esperar a que se complete la desinstalación
        }

        // Crear el servicio usando sc.exe
        var createArgs = $"create \"{ServiceName}\" binPath= \"\"{serviceExePath}\"\" DisplayName= \"{ServiceDisplayName}\" start= auto";
        var result = RunCommand("sc.exe", createArgs);

        if (result != 0)
        {
            Console.WriteLine("ERROR: No se pudo crear el servicio.");
            return 1;
        }

        // Configurar descripción
        var descArgs = $"description \"{ServiceName}\" \"{ServiceDescription}\"";
        RunCommand("sc.exe", descArgs);

        // Configurar recuperación automática (CAPA 2 del Watchdog)
        ConfigureServiceRecovery();

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("✓ Servicio instalado correctamente.");
        Console.ResetColor();

        // Intentar iniciar el servicio
        Console.WriteLine("Iniciando servicio...");
        var startArgs = $"start \"{ServiceName}\"";
        result = RunCommand("sc.exe", startArgs);

        if (result == 0)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✓ Servicio iniciado correctamente.");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("⚠ El servicio se instaló pero no se pudo iniciar automáticamente.");
            Console.WriteLine("  Puede iniciarlo manualmente desde services.msc");
            Console.ResetColor();
        }

        return 0;
    }

    static void ConfigureServiceRecovery()
    {
        Console.WriteLine("Configurando recuperación automática del servicio...");

        // Configurar acciones de recuperación:
        // - Primer fallo: Reiniciar después de 1 minuto (60000 ms)
        // - Segundo fallo: Reiniciar después de 2 minutos (120000 ms)
        // - Fallos subsecuentes: Reiniciar después de 5 minutos (300000 ms)
        // - Reset del contador de fallos después de 24 horas (86400 segundos)
        
        var recoveryArgs = $"failure \"{ServiceName}\" reset= 86400 actions= restart/60000/restart/120000/restart/300000";
        var result = RunCommand("sc.exe", recoveryArgs);

        if (result == 0)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✓ Recuperación automática configurada:");
            Console.WriteLine("  - 1er fallo: Reinicio en 1 minuto");
            Console.WriteLine("  - 2do fallo: Reinicio en 2 minutos");
            Console.WriteLine("  - 3er+ fallo: Reinicio en 5 minutos");
            Console.WriteLine("  - Reset de contador: 24 horas");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("⚠ No se pudo configurar la recuperación automática.");
            Console.WriteLine("  Puede configurarla manualmente desde services.msc");
            Console.ResetColor();
        }
    }

    static int UninstallService()
    {
        if (!ServiceExists(ServiceName))
        {
            Console.WriteLine("El servicio no está instalado.");
            return 0;
        }

        Console.WriteLine($"Desinstalando servicio '{ServiceDisplayName}'...");

        // Detener el servicio si está corriendo
        try
        {
            using var controller = new ServiceController(ServiceName);
            if (controller.Status != ServiceControllerStatus.Stopped)
            {
                Console.WriteLine("Deteniendo servicio...");
                controller.Stop();
                controller.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30));
                Console.WriteLine("✓ Servicio detenido.");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Advertencia al detener servicio: {ex.Message}");
        }

        // Eliminar el servicio
        var deleteArgs = $"delete \"{ServiceName}\"";
        var result = RunCommand("sc.exe", deleteArgs);

        if (result == 0)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✓ Servicio desinstalado correctamente.");
            Console.ResetColor();
            return 0;
        }
        else
        {
            Console.WriteLine("ERROR: No se pudo desinstalar el servicio.");
            return 1;
        }
    }

    static int ShowStatus()
    {
        if (!ServiceExists(ServiceName))
        {
            Console.WriteLine($"Estado: NO INSTALADO");
            return 0;
        }

        try
        {
            using var controller = new ServiceController(ServiceName);
            Console.WriteLine($"Servicio: {ServiceDisplayName}");
            Console.WriteLine($"Nombre: {ServiceName}");
            Console.WriteLine($"Estado: {GetStatusText(controller.Status)}");
            Console.WriteLine($"Tipo de inicio: {controller.StartType}");
            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"ERROR al obtener estado: {ex.Message}");
            return 1;
        }
    }

    static bool ServiceExists(string serviceName)
    {
        try
        {
            using var controller = new ServiceController(serviceName);
            var status = controller.Status; // Esto lanzará excepción si no existe
            return true;
        }
        catch
        {
            return false;
        }
    }

    static string GetStatusText(ServiceControllerStatus status)
    {
        return status switch
        {
            ServiceControllerStatus.Running => "EN EJECUCIÓN",
            ServiceControllerStatus.Stopped => "DETENIDO",
            ServiceControllerStatus.Paused => "PAUSADO",
            ServiceControllerStatus.StartPending => "INICIANDO...",
            ServiceControllerStatus.StopPending => "DETENIENDO...",
            _ => status.ToString()
        };
    }

    static int RunCommand(string fileName, string arguments)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = Process.Start(startInfo);
        if (process == null)
        {
            Console.WriteLine($"ERROR: No se pudo ejecutar {fileName}");
            return 1;
        }

        process.WaitForExit();
        return process.ExitCode;
    }
}
