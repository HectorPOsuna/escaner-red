using NetworkScanner.Shared;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace NetworkScanner.Service
{
    public class Program
    {
        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().Run();
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
