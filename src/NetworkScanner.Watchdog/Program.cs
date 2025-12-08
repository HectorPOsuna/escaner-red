using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using System.Diagnostics;

namespace NetworkScanner.Watchdog
{
    public class Program
    {
        private const string EventSourceName = "NetworkScannerWatchdog";
        private const string EventLogName = "Application";

        public static void Main(string[] args)
        {
            // Configurar Event Viewer source
            SetupEventSource();

            CreateHostBuilder(args).Build().Run();
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
                // Si no tiene permisos, el servicio seguirá funcionando
            }
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .UseWindowsService(options =>
                {
                    options.ServiceName = "NetworkScannerWatchdog";
                })
                .ConfigureServices((hostContext, services) =>
                {
                    services.AddHostedService<WatchdogWorker>();
                });
    }
}
