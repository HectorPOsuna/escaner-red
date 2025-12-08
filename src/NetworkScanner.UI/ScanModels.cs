namespace NetworkScanner.UI
{
    public class ScanConfig
    {
        public string SubnetPrefix { get; set; } = "";
        public string RangeStart { get; set; } = "";
        public string RangeEnd { get; set; } = "";
        public string OperationMode { get; set; } = "api"; // "api", "hybrid", "monitor"
        public bool SingleScan { get; set; } = false;
        public bool ContinuousMode { get; set; } = false;
        public int IntervalMinutes { get; set; } = 5;
    }

    public class ScanProgress
    {
        public int Current { get; set; }
        public int Total { get; set; }
        public int Percentage { get; set; }
        public string CurrentIP { get; set; } = "";
    }

    public class ClientMetrics
    {
        public string Hostname { get; set; } = "";
        public string IP { get; set; } = "";
        public string OS { get; set; } = "";
        public double CpuUsage { get; set; }
        public double RamAvailableMb { get; set; }
        public double DiskFreeGb { get; set; }
        public double DiskTotalGb { get; set; }
        public DateTime Timestamp { get; set; }
    }
}
