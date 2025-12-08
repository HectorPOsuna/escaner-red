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

        private async Task MonitorLoop()
        {
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

                    // TODO: Aquí enviaríamos a la API si fuera necesario
                    // SendMetricsToApi(metrics);
                }
                catch 
                {
                    // Ignorar errores puntuales
                }

                await Task.Delay(_intervalMs);
            }
        }
    }
}
