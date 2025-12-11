using System;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using NetworkScanner.Shared;

namespace NetworkScanner.UI
{
    public class ScanController
    {
        private const string ProgressFileName = "progress.json";
        private const string ConfigFileName = "temp_scan_config.json";
        
        // Evento para notificar progreso a la UI
        public event Action<ScanProgress>? OnProgressUpdated;
        public event Action? OnScanCompleted;

        private bool _isScanning;

        public async Task StartScanAsync(string subnet, string startIp, string endIp, bool isManualMode)
        {
            _isScanning = true;

            // 1. Preparar configuración
            var config = new
            {
                SubnetPrefix = subnet,
                StartIP = startIp,
                EndIP = endIp,
                OperationMode = isManualMode ? "api" : "hybrid",
                // Si es manual, podríamos querer forzar una sola ejecución en el PS1
                // Pero el PS1 actual corre una vez por defecto.
                EnableProgress = true,
                ProgressFile = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ProgressFileName)
            };

            string configJson = JsonSerializer.Serialize(config);
            string configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ConfigFileName);
            File.WriteAllText(configPath, configJson);

            // 2. Limpiar progreso anterior
            if (File.Exists(config.ProgressFile))
                File.Delete(config.ProgressFile);

            // 3. Obtener ruta del script
            // Usamos PathResolver para encontrar el script, o fallback a una ruta relativa conocida
            string? scriptPath = PathResolver.GetAgentScriptPath();
            if (string.IsNullOrEmpty(scriptPath) || !File.Exists(scriptPath))
            {
                // Fallback para desarrollo si PathResolver falla o devuelve null
                scriptPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "..", "agent", "NetworkScanner.ps1");
                if (!File.Exists(scriptPath))
                {
                     throw new FileNotFoundException("No se encontró el script NetworkScanner.ps1");
                }
            }

            // 4. Iniciar proceso PowerShell
            var psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                // Pasamos el archivo de configuración como parámetro (el script debe soportarlo)
                // Implementaremos en el script la lectura de este JSON o argumentos
                Arguments = $"-ExecutionPolicy Bypass -File \"{scriptPath}\" -ConfigFile \"{configPath}\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            await Task.Run(async () =>
            {
                using (var process = Process.Start(psi))
                {
                    if (process == null) return;

                    // Monitorear progreso en un loop aparte
                    _ = MonitorProgressLoop(config.ProgressFile);

                    // Esperar a que termine
                    await process.WaitForExitAsync();
                    
                    _isScanning = false;
                    OnScanCompleted?.Invoke();
                }
            });
        }

        private async Task MonitorProgressLoop(string progressFilePath)
        {
            while (_isScanning)
            {
                try
                {
                    if (File.Exists(progressFilePath))
                    {
                        // Intentar leer con reintentos por si está siendo escrito
                        string json = "";
                        try 
                        {
                            using (var fs = new FileStream(progressFilePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                            using (var sr = new StreamReader(fs))
                            {
                                json = await sr.ReadToEndAsync();
                            }
                        }
                        catch { /* Ignorar errores de bloqueo momentáneo */ }

                        if (!string.IsNullOrWhiteSpace(json))
                        {
                            var progress = JsonSerializer.Deserialize<ScanProgress>(json);
                            if (progress != null)
                            {
                                OnProgressUpdated?.Invoke(progress);
                            }
                        }
                    }
                }
                catch { /* Ignorar errores de lectura */ }

                await Task.Delay(500); // 0.5 segundos
            }
        }

        public void StopScan()
        {
            // Implementar cancelación si es necesario (kill process)
            _isScanning = false;
        }
    }
}
