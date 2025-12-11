using System;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace NetworkScanner.UI
{
    public class MonitorController
    {
        private bool _isMonitoring;
        private Task? _monitorTask;
        private readonly int _intervalMs = 5000; // 5 segundos

        public event Action<ClientMetrics>? OnMetricsUpdated;

        public bool IsMonitoring => _isMonitoring;

        public void StartMonitoring()
        {
            if (_isMonitoring) return;

            _isMonitoring = true;
            _monitorTask = Task.Run(MonitorLoop);
        }

        public void StopMonitoring()
        {
            _isMonitoring = false;
        }

        public string ApiUrl { get; set; } = "http://dsantana.fimaz.uas.edu.mx/server/api/receive.php";

        private async Task MonitorLoop()
        {
            using var client = new System.Net.Http.HttpClient();
            
            while (_isMonitoring)
            {
                try
                {
                    var sysInfo = SystemMetrics.GetSystemInfo();
                    var diskInfo = SystemMetrics.GetDiskInfo();

                    var metrics = new ClientMetrics
                    {
                        Hostname = sysInfo.Hostname,
                        IP = sysInfo.IP,
                        OS = sysInfo.OS,
                        CpuUsage = SystemMetrics.GetCpuUsage(),
                        RamAvailableMb = SystemMetrics.GetAvailableRam(),
                        DiskFreeGb = diskInfo.FreeGb,
                        DiskTotalGb = diskInfo.TotalGb,
                        Timestamp = DateTime.Now
                    };

                    OnMetricsUpdated?.Invoke(metrics);

                    await SendMetricsToApi(client, metrics);
                }
                catch 
                {
                    // Ignorar errores puntuales
                }

                await Task.Delay(_intervalMs);
            }
        }

        private async Task SendMetricsToApi(System.Net.Http.HttpClient client, ClientMetrics metrics)
        {
            if (string.IsNullOrEmpty(ApiUrl)) return;

            try
            {
                var payload = new
                {
                    type = "metrics",
                    data = metrics
                };

                var json = JsonSerializer.Serialize(payload);
                var content = new System.Net.Http.StringContent(json, System.Text.Encoding.UTF8, "application/json");

                await client.PostAsync(ApiUrl, content);
            }
            catch
            {
                // Silent fail for metrics
            }
        }
    }
}
