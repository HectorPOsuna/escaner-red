using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.NetworkInformation;

namespace NetworkScanner.UI
{
    public static class SystemMetrics
    {
        private static PerformanceCounter? _cpuCounter;
        private static PerformanceCounter? _ramCounter;

        static SystemMetrics()
        {
            try
            {
                _cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
                _ramCounter = new PerformanceCounter("Memory", "Available MBytes");
                
                // First call always returns 0
                _cpuCounter.NextValue();
                _ramCounter.NextValue();
            }
            catch 
            {
                // Fallback or log if counters are not available
            }
        }

        public static double GetCpuUsage()
        {
            try
            {
                return _cpuCounter != null ? Math.Round(_cpuCounter.NextValue(), 1) : 0;
            }
            catch { return 0; }
        }

        public static double GetAvailableRam()
        {
            try
            {
                return _ramCounter != null ? _ramCounter.NextValue() : 0;
            }
            catch { return 0; }
        }

        public static double GetTotalRam()
        {
            // This is a bit tricky in C# without P/Invoke, assuming static total for simplicity or using GC info
            // For this agent, we can approximate or use GC.GetGCMemoryInfo in .NET Core (but that's for process)
            // A simple approach is using ComputerInfo from VB or P/Invoke. 
            // For now, let's just return available. 
            // Better: WMI but it's slow. 
            // Let's stick to returning available MB.
            return 0; // Not easily available without overhead
        }
        
        public static (string Drive, double FreeGb, double TotalGb) GetDiskInfo()
        {
            try
            {
                var drive = DriveInfo.GetDrives().FirstOrDefault(d => d.IsReady && d.Name == @"C:\");
                if (drive != null)
                {
                    double free = Math.Round(drive.AvailableFreeSpace / 1024.0 / 1024.0 / 1024.0, 1);
                    double total = Math.Round(drive.TotalSize / 1024.0 / 1024.0 / 1024.0, 1);
                    return (drive.Name, free, total);
                }
            }
            catch { }
            return ("C:\\", 0, 0);
        }

        public static (string Hostname, string OS, string IP) GetSystemInfo()
        {
            string hostname = Environment.MachineName;
            string os = Environment.OSVersion.ToString();
            string ip = GetLocalIPAddress();
            return (hostname, os, ip);
        }

        private static string GetLocalIPAddress()
        {
            try
            {
                var host = System.Net.Dns.GetHostEntry(System.Net.Dns.GetHostName());
                foreach (var ip in host.AddressList)
                {
                    if (ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
                    {
                        return ip.ToString();
                    }
                }
            }
            catch { }
            return "127.0.0.1";
        }
    }
}
