using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace NetworkScannerService
{
    /// <summary>
    /// Punto de entrada del servicio de Windows
    /// </summary>
    public class Program
    {
        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().Run();
        }

        /// <summary>
        /// Configura el host del servicio de Windows
        /// </summary>
        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .UseWindowsService(options =>
                {
                    options.ServiceName = "NetworkScannerService";
                })
                .ConfigureServices((hostContext, services) =>
                {
                    // Configurar opciones
                    services.Configure<ScannerSettings>(hostContext.Configuration.GetSection("ScannerSettings"));

                    // Registrar HttpClient
                    services.AddHttpClient();

                    // Registrar el servicio worker
                    services.AddHostedService<ScannerWorker>();
                });
    }
}
