namespace NetworkScanner.UI
{
    public class ScanConfig
    {
        public string SubnetPrefix { get; set; } = "";
        public string OperationMode { get; set; } = "api"; // "api" or "hybrid"
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
}
