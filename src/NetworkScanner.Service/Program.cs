using NetworkScanner.Shared;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using System.Diagnostics;
using System.Threading.Tasks;

namespace NetworkScanner.Service
{
    public class Program
    {
        private const string EventSourceName = "NetworkScannerService";
        private const string EventLogName = "Application";

        public static void Main(string[] args)
        {
            // Configurar Event Viewer source
            SetupEventSource();

            // Configurar global exception handlers
            AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;
            TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;

            try
            {
                CreateHostBuilder(args).Build().Run();
            }
            catch (Exception ex)
            {
                LogCriticalError("Error fatal en Main", ex);
                throw;
            }
        }

        private static void SetupEventSource()
        {
            try
            {
                if (!EventLog.SourceExists(EventSourceName))
                {
                    EventLog.CreateEventSource(EventSourceName, EventLogName);
                }
            }
            catch
            {
                // Si no tiene permisos, el servicio seguirá funcionando sin Event Viewer
            }
        }

        private static void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            var exception = e.ExceptionObject as Exception;
            LogCriticalError("Excepción no controlada en AppDomain", exception);
            
            // Dar tiempo para que se escriban los logs
            System.Threading.Thread.Sleep(1000);
        }

        private static void OnUnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs e)
        {
            LogCriticalError("Excepción no observada en Task", e.Exception);
            e.SetObserved(); // Prevenir que termine el proceso
        }

        private static void LogCriticalError(string message, Exception? exception)
        {
            try
            {
                var eventLog = new EventLog(EventLogName)
                {
                    Source = EventSourceName
                };

                string fullMessage = $"{message}\n\nDetalles:\n{exception?.ToString() ?? "Sin detalles"}";
                eventLog.WriteEntry(fullMessage, EventLogEntryType.Error, 1001);
            }
            catch
            {
                // Fallback: escribir a consola si Event Viewer falla
                Console.WriteLine($"CRITICAL ERROR: {message}");
                Console.WriteLine(exception?.ToString());
            }
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .UseWindowsService(options =>
                {
                    options.ServiceName = "NetworkScannerService";
                })
                .ConfigureServices((hostContext, services) =>
                {
                    // Bind configuration
                    services.Configure<ScannerSettings>(hostContext.Configuration.GetSection("ScannerSettings"));

                    // Register HttpClient
                    services.AddHttpClient();

                    // Register Worker
                    services.AddHostedService<ScannerWorker>();
                });
    }
}
