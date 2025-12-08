namespace NetworkScannerService
{
    public class ScannerSettings
    {
        public int IntervalMinutes { get; set; }
        public string ScriptPath { get; set; }
        public int TimeoutMinutes { get; set; }
        public string ApiUrl { get; set; }
        public bool EnableDetailedLogging { get; set; }
    }
}
