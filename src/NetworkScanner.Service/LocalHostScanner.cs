using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace NetworkScanner.Service
{
    public class LocalHostScanner
    {
        private static readonly Dictionary<(int Port, string Type), PortInternalState> _portStates = new();
        private static readonly List<PortHistoryEntry> _globalHistory = new();
        private const int MAX_HISTORY_ITEMS = 1000;

        public async Task<LocalHostScanResult> ScanAsync()
        {
            var result = new LocalHostScanResult
            {
                host_info = GetHostInfo(),
                network_interfaces = GetNetworkInterfaces(),
                scan_time_utc = DateTime.UtcNow
            };

            // Detect Current Open Ports
            var currentOpenPorts = GetCurrentOpenPorts();
            
            // Process port states and detect changes
            UpdatePortStates(currentOpenPorts, result);

            return result;
        }

        private HostInfo GetHostInfo()
        {
            return new HostInfo
            {
                hostname = Dns.GetHostName(),
                os_name = RuntimeInformation.OSDescription,
                os_version = Environment.OSVersion.VersionString,
                manufacturer = GetSystemManufacturer()
            };
        }

        private List<NetworkInterfaceInfo> GetNetworkInterfaces()
        {
            var interfaces = new List<NetworkInterfaceInfo>();
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                var ipProps = ni.GetIPProperties();
                var ipv4 = ipProps.UnicastAddresses
                    .FirstOrDefault(ua => ua.Address.AddressFamily == AddressFamily.InterNetwork);

                if (ipv4 == null && ni.OperationalStatus != OperationalStatus.Up) continue;

                var mac = ni.GetPhysicalAddress().ToString();
                if (!string.IsNullOrEmpty(mac) && mac.Length == 12)
                {
                    mac = string.Join(":", Enumerable.Range(0, 6).Select(i => mac.Substring(i * 2, 2)));
                }

                interfaces.Add(new NetworkInterfaceInfo
                {
                    name = ni.Name,
                    description = ni.Description,
                    ip_address = ipv4?.Address.ToString() ?? "N/A",
                    mac_address = mac,
                    status = ni.OperationalStatus.ToString(),
                    is_primary = ni.GetIPProperties().GatewayAddresses.Count > 0
                });
            }
            return interfaces;
        }

        private List<(int Port, string Type)> GetCurrentOpenPorts()
        {
            var openPorts = new List<(int Port, string Type)>();
            try
            {
                var properties = IPGlobalProperties.GetIPGlobalProperties();
                
                // TCP
                var tcpListeners = properties.GetActiveTcpListeners();
                foreach (var listener in tcpListeners)
                {
                    openPorts.Add((listener.Port, "TCP"));
                }

                // UDP
                var udpListeners = properties.GetActiveUdpListeners();
                foreach (var listener in udpListeners)
                {
                    // Filter ephemeral ports as previously done
                    if (listener.Port < 49152)
                    {
                        openPorts.Add((listener.Port, "UDP"));
                    }
                }
            }
            catch { /* Ignore errors in service context */ }
            return openPorts.Distinct().ToList();
        }

        private void UpdatePortStates(List<(int Port, string Type)> currentOpen, LocalHostScanResult result)
        {
            var now = DateTime.UtcNow;
            var currentKeys = new HashSet<(int Port, string Type)>(currentOpen);

            // 1. Detect Opened or Maintained ports
            foreach (var key in currentKeys)
            {
                if (!_portStates.TryGetValue(key, out var state))
                {
                    state = new PortInternalState { Port = key.Port, Type = key.Type, IsOpen = true, LastOpened = now };
                    _portStates[key] = state;
                    AddHistoryEntry(key.Port, key.Type, "OPENED", now);
                }
                else if (!state.IsOpen)
                {
                    state.IsOpen = true;
                    state.LastOpened = now;
                    AddHistoryEntry(key.Port, key.Type, "OPENED", now);
                }
                
                result.ports_snapshot.Add(new PortSnapshotEntry
                {
                    port = state.Port,
                    type = state.Type,
                    status = "OPEN",
                    detected_at_utc = state.LastOpened ?? now
                });
            }

            // 2. Detect Closed ports (were in state but not in current)
            foreach (var state in _portStates.Values.Where(s => s.IsOpen))
            {
                var key = (state.Port, state.Type);
                if (!currentKeys.Contains(key))
                {
                    state.IsOpen = false;
                    state.LastClosed = now;
                    AddHistoryEntry(state.Port, state.Type, "CLOSED", now);
                }
            }

            // 3. Populate history in result (send last N events or all since last check)
            // For now, we send the whole history buffer
            result.ports_history.AddRange(_globalHistory);
        }

        private void AddHistoryEntry(int port, string type, string eventType, DateTime timestamp)
        {
            lock (_globalHistory)
            {
                _globalHistory.Add(new PortHistoryEntry
                {
                    port = port,
                    type = type,
                    @event = eventType,
                    timestamp_utc = timestamp
                });

                if (_globalHistory.Count > MAX_HISTORY_ITEMS)
                {
                    _globalHistory.RemoveAt(0);
                }
            }
        }

        private string GetSystemManufacturer()
        {
            try
            {
                if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                {
                    using var key = Registry.LocalMachine.OpenSubKey(@"HARDWARE\DESCRIPTION\System\BIOS");
                    return key?.GetValue("SystemManufacturer")?.ToString() ?? "Unknown";
                }
            }
            catch { }
            return "Unknown";
        }

        private class PortInternalState
        {
            public int Port { get; set; }
            public string Type { get; set; } = string.Empty;
            public bool IsOpen { get; set; }
            public DateTime? LastOpened { get; set; }
            public DateTime? LastClosed { get; set; }
        }
    }

    // --- DTOs for API ---

    public class LocalHostScanResult
    {
        public HostInfo host_info { get; set; } = new();
        public List<NetworkInterfaceInfo> network_interfaces { get; set; } = new();
        public List<PortSnapshotEntry> ports_snapshot { get; set; } = new();
        public List<PortHistoryEntry> ports_history { get; set; } = new();
        public DateTime scan_time_utc { get; set; }
    }

    public class HostInfo
    {
        public string hostname { get; set; } = string.Empty;
        public string os_name { get; set; } = string.Empty;
        public string os_version { get; set; } = string.Empty;
        public string manufacturer { get; set; } = string.Empty;
    }

    public class NetworkInterfaceInfo
    {
        public string name { get; set; } = string.Empty;
        public string description { get; set; } = string.Empty;
        public string ip_address { get; set; } = string.Empty;
        public string mac_address { get; set; } = string.Empty;
        public string status { get; set; } = string.Empty;
        public bool is_primary { get; set; }
    }

    public class PortSnapshotEntry
    {
        public int port { get; set; }
        public string type { get; set; } = string.Empty;
        public string status { get; set; } = string.Empty;
        public DateTime detected_at_utc { get; set; }
    }

    public class PortHistoryEntry
    {
        public int port { get; set; }
        public string type { get; set; } = string.Empty;
        public string @event { get; set; } = string.Empty; // OPENED, CLOSED
        public DateTime timestamp_utc { get; set; }
    }
}
