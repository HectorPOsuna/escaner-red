namespace NetworkScanner.Shared
{
    public class ScannerSettings
    {
        public int IntervalMinutes { get; set; } = 5;
        public string ScriptPath { get; set; } = "";
        public int TimeoutMinutes { get; set; } = 10;
        public string ApiUrl { get; set; } = "http://localhost/escaner-red/server/api/receive.php";
        public bool EnableDetailedLogging { get; set; } = true;
    }
}
