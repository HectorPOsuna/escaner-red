using System;
using System.IO;

namespace NetworkScanner.Shared
{
    /// <summary>
    /// Centralized path resolver for NetworkScanner application.
    /// Handles path resolution for different deployment scenarios (dev, production, installer).
    /// </summary>
    public static class PathResolver
    {
        // Installation root directory (set by installer)
        private const string INSTALL_ROOT = @"C:\Program Files\NetworkScanner";
        
        // Service executable name
        private const string SERVICE_EXE_NAME = "NetworkScanner.Service.exe";
        
        // Watchdog executable name
        private const string WATCHDOG_EXE_NAME = "NetworkScanner.Watchdog.exe";
        
        /// <summary>
        /// Gets the full path to the service executable.
        /// Tries multiple locations in order of priority.
        /// </summary>
        /// <returns>Full path to service executable, or null if not found</returns>
        public static string? GetServiceExecutablePath()
        {
            // Priority 1: Production installation (C:\Program Files\NetworkScanner\Service\)
            string productionPath = Path.Combine(INSTALL_ROOT, "Service", SERVICE_EXE_NAME);
            if (File.Exists(productionPath))
                return productionPath;

            // Priority 2: Same directory as UI (legacy/simple deployment)
            string uiDir = AppDomain.CurrentDomain.BaseDirectory;
            string sameDirPath = Path.Combine(uiDir, SERVICE_EXE_NAME);
            if (File.Exists(sameDirPath))
                return sameDirPath;

            // Priority 3: Sibling Service directory (if UI is in UI\ subfolder)
            string parentDir = Directory.GetParent(uiDir)?.FullName;
            if (parentDir != null)
            {
                string siblingPath = Path.Combine(parentDir, "Service", SERVICE_EXE_NAME);
                if (File.Exists(siblingPath))
                    return siblingPath;
            }

            // Priority 4: Development environment (relative to UI project)
            // This handles running from Visual Studio
            string devPath = Path.GetFullPath(Path.Combine(uiDir, @"..\..\..\NetworkScanner.Service\bin\Debug\net8.0\NetworkScanner.Service.exe"));
            if (File.Exists(devPath))
                return devPath;

            // Also try Release
            string devReleasePath = Path.GetFullPath(Path.Combine(uiDir, @"..\..\..\NetworkScanner.Service\bin\Release\net8.0\NetworkScanner.Service.exe"));
            if (File.Exists(devReleasePath))
                return devReleasePath;

            // Not found
            return null;
        }

        /// <summary>
        /// Gets the full path to the watchdog executable.
        /// </summary>
        public static string? GetWatchdogExecutablePath()
        {
            // Production installation
            string productionPath = Path.Combine(INSTALL_ROOT, "Watchdog", WATCHDOG_EXE_NAME);
            if (File.Exists(productionPath))
                return productionPath;

            // Same directory as UI
            string uiDir = AppDomain.CurrentDomain.BaseDirectory;
            string sameDirPath = Path.Combine(uiDir, WATCHDOG_EXE_NAME);
            if (File.Exists(sameDirPath))
                return sameDirPath;

            // Sibling directory
            string parentDir = Directory.GetParent(uiDir)?.FullName;
            if (parentDir != null)
            {
                string siblingPath = Path.Combine(parentDir, "Watchdog", WATCHDOG_EXE_NAME);
                if (File.Exists(siblingPath))
                    return siblingPath;
            }

            return null;
        }

        /// <summary>
        /// Gets the path to the service's appsettings.json file.
        /// </summary>
        public static string? GetServiceConfigPath()
        {
            // Production
            string productionPath = Path.Combine(INSTALL_ROOT, "Service", "appsettings.json");
            if (File.Exists(productionPath))
                return productionPath;

            // Same directory as service executable
            string? serviceExe = GetServiceExecutablePath();
            if (serviceExe != null)
            {
                string configPath = Path.Combine(Path.GetDirectoryName(serviceExe)!, "appsettings.json");
                if (File.Exists(configPath))
                    return configPath;
            }

            // UI directory (fallback)
            string uiDir = AppDomain.CurrentDomain.BaseDirectory;
            string uiConfigPath = Path.Combine(uiDir, "appsettings.json");
            if (File.Exists(uiConfigPath))
                return uiConfigPath;

            return null;
        }

        /// <summary>
        /// Gets the logs directory path.
        /// </summary>
        public static string GetLogsDirectory()
        {
            return @"C:\Logs\NetworkScanner";
        }

        /// <summary>
        /// Gets the PowerShell agent script path.
        /// </summary>
        public static string? GetAgentScriptPath()
        {
            // Production
            string productionPath = Path.Combine(INSTALL_ROOT, "Agent", "NetworkScanner.ps1");
            if (File.Exists(productionPath))
                return productionPath;

            // Development
            string uiDir = AppDomain.CurrentDomain.BaseDirectory;
            string devPath = Path.GetFullPath(Path.Combine(uiDir, @"..\..\..\..\..\agent\NetworkScanner.ps1"));
            if (File.Exists(devPath))
                return devPath;

            return null;
        }

        /// <summary>
        /// Validates that all required paths exist for installation.
        /// </summary>
        /// <param name="missingPaths">List of missing paths</param>
        /// <returns>True if all paths are valid</returns>
        public static bool ValidateInstallation(out string[] missingPaths)
        {
            var missing = new System.Collections.Generic.List<string>();

            if (GetServiceExecutablePath() == null)
                missing.Add($"Service executable ({SERVICE_EXE_NAME})");

            if (GetServiceConfigPath() == null)
                missing.Add("Service configuration (appsettings.json)");

            if (GetAgentScriptPath() == null)
                missing.Add("PowerShell agent script (NetworkScanner.ps1)");

            missingPaths = missing.ToArray();
            return missing.Count == 0;
        }
    }
}
