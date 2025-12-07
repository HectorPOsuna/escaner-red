using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NetworkScanner.Shared;
using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace NetworkScanner.Service
{
    public class ScannerWorker : BackgroundService
    {
        private readonly ILogger<ScannerWorker> _logger;
        private readonly ScannerSettings _settings;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly string _logDirectory;
        private readonly string _logFilePath;

        public ScannerWorker(
            ILogger<ScannerWorker> logger,
            IOptions<ScannerSettings> settings,
            IHttpClientFactory httpClientFactory)
        {
            _logger = logger;
            _settings = settings.Value;
            _httpClientFactory = httpClientFactory;

            // Carpeta de logs: C:\ProgramData\NetworkScanner\Logs o local
            // Para simplicidad por ahora usamos una ruta fija accesible
            _logDirectory = @"C:\Logs\NetworkScanner";
            
            if (!Directory.Exists(_logDirectory))
            {
                Directory.CreateDirectory(_logDirectory);
            }

            _logFilePath = Path.Combine(_logDirectory, $"service_{DateTime.Now:yyyyMMdd}.log");
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            LogConTimestamp($"Servicio Iniciado. Intervalo: {_settings.IntervalMinutes} min. Script: {_settings.ScriptPath}");
            _logger.LogInformation("NetworkScannerService iniciado.");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await EjecutarCicloEscaneo(stoppingToken);
                    await Task.Delay(TimeSpan.FromMinutes(_settings.IntervalMinutes), stoppingToken);
                }
                catch (TaskCanceledException) { break; }
                catch (Exception ex)
                {
                    LogConTimestamp($"ERROR FATAL: {ex.Message}");
                    _logger.LogError(ex, "Error fatal en el ciclo del servicio");
                    await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
                }
            }
        }

        private async Task EjecutarCicloEscaneo(CancellationToken stoppingToken)
        {
            LogConTimestamp("--- Iniciando ciclo de escaneo ---");
            
            try
            {
                if (!File.Exists(_settings.ScriptPath))
                {
                    LogConTimestamp($"El script no existe: {_settings.ScriptPath}");
                    return; 
                }

                string scriptDir = Path.GetDirectoryName(_settings.ScriptPath);
                string resultsFile = Path.Combine(scriptDir, "scan_results.json");

                // Ejecución PowerShell
                var processInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-NonInteractive -NoProfile -ExecutionPolicy Bypass -File \"{_settings.ScriptPath}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    WorkingDirectory = scriptDir
                };

                using (var process = new Process { StartInfo = processInfo })
                {
                    var output = new StringBuilder();
                    var error = new StringBuilder();

                    process.OutputDataReceived += (s, e) => { if (e.Data != null) output.AppendLine(e.Data); };
                    process.ErrorDataReceived += (s, e) => { if (e.Data != null) error.AppendLine(e.Data); };

                    process.Start();
                    process.BeginOutputReadLine();
                    process.BeginErrorReadLine();

                    var cts = new CancellationTokenSource(TimeSpan.FromMinutes(_settings.TimeoutMinutes));
                    try
                    {
                        await process.WaitForExitAsync(cts.Token);
                    }
                    catch (OperationCanceledException)
                    {
                        process.Kill();
                        LogConTimestamp("Timeout excedido - Proceso terminado.");
                        throw;
                    }

                    if (process.ExitCode != 0)
                    {
                        LogConTimestamp($"Script finalizó con error {process.ExitCode}: {error}");
                    }
                    else
                    {
                        if (_settings.EnableDetailedLogging) LogConTimestamp("Script finalizado correctamente.");
                    }
                }

                // Procesamiento JSON
                if (File.Exists(resultsFile))
                {
                    string json = await File.ReadAllTextAsync(resultsFile, stoppingToken);
                    // Validar
                    using (JsonDocument.Parse(json)) { }
                    
                    await EnviarResultadosApi(json, stoppingToken);
                }
                else
                {
                    LogConTimestamp("No se generó scan_results.json");
                }

            }
            catch (Exception ex)
            {
                LogConTimestamp($"Error en ciclo: {ex.Message}");
            }
        }

        private async Task EnviarResultadosApi(string json, CancellationToken token)
        {
            if (string.IsNullOrEmpty(_settings.ApiUrl)) return;

            try
            {
                var client = _httpClientFactory.CreateClient();
                // Timeout corto para la API
                client.Timeout = TimeSpan.FromSeconds(30);

                var content = new StringContent(json, Encoding.UTF8, "application/json");
                var response = await client.PostAsync(_settings.ApiUrl, content, token);

                if (response.IsSuccessStatusCode)
                {
                    LogConTimestamp("Datos enviados a API exitosamente.");
                }
                else
                {
                    LogConTimestamp($"API Error {response.StatusCode}");
                }
            }
            catch (Exception ex)
            {
                LogConTimestamp($"Error envío API: {ex.Message}");
            }
        }

        public override async Task StopAsync(CancellationToken stoppingToken)
        {
            LogConTimestamp("Servicio DETENIÉNDOSE...");
            await base.StopAsync(stoppingToken);
        }

        private void LogConTimestamp(string mensaje)
        {
            try
            {
                string entry = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {mensaje}";
                if (Environment.UserInteractive) Console.WriteLine(entry);
                
                lock (this)
                {
                    File.AppendAllText(_logFilePath, entry + Environment.NewLine);
                }
            }
            catch { }
        }
    }
}
