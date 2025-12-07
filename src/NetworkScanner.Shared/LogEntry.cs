using System;

namespace NetworkScanner.Shared
{
    public class LogEntry
    {
        public DateTime Timestamp { get; set; }
        public string Message { get; set; }
        public string Type { get; set; } // INFO, ERROR, WARNING
    }
}
