using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace NetworkScannerService
{
    /// <summary>
    /// Worker del servicio que ejecuta el agente de escaneo periódicamente
    /// </summary>
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

            // Usar ProgramData para logs (Standard Windows Practice)
            string commonData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
            _logDirectory = Path.Combine(commonData, "NetworkScanner", "Logs"); 

            if (!Directory.Exists(_logDirectory))
            {
                Directory.CreateDirectory(_logDirectory);
            }

            _logFilePath = Path.Combine(_logDirectory, $"service_{DateTime.Now:yyyyMMdd}.log");
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            LogConTimestamp("Servicio INICIADO.");
            _logger.LogInformation("NetworkScannerService iniciado. Intervalo: {minutes} minutos", _settings.IntervalMinutes);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await EjecutarCicloEscaneo(stoppingToken);

                    // Esperar el intervalo configurado
                    await Task.Delay(TimeSpan.FromMinutes(_settings.IntervalMinutes), stoppingToken);
                }
                catch (TaskCanceledException)
                {
                    // Servicio deteniéndose
                    break;
                }
                catch (Exception ex)
                {
                    LogConTimestamp($"ERROR FATAL en bucle principal: {ex.Message}");
                    _logger.LogError(ex, "Error fatal en el ciclo del servicio");
                    
                    // Esperar un poco antes de reintentar para no saturar en caso de fallo continuo
                    await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
                }
            }
        }

        private async Task EjecutarCicloEscaneo(CancellationToken stoppingToken)
        {
            LogConTimestamp("=== Iniciando ciclo de escaneo ===");
            var stopwatch = Stopwatch.StartNew();

            try
            {
                string scriptPath = _settings.ScriptPath;

                // 1. Resolver ruta del script
                if (string.IsNullOrWhiteSpace(scriptPath))
                {
                    // Default relative to executable
                    scriptPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Agent", "NetworkScanner.ps1");
                }
                else if (!Path.IsPathRooted(scriptPath))
                {
                    // Relative setup
                    scriptPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, scriptPath);
                }

                if (!File.Exists(scriptPath))
                {
                    throw new FileNotFoundException($"El script no existe en: {scriptPath}");
                }

                string scriptDir = Path.GetDirectoryName(scriptPath);
                string resultsFile = Path.Combine(scriptDir, "scan_results.json");

                // 2. Ejecutar PowerShell
                LogConTimestamp($"Ejecutando script: {scriptPath}");
                
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

                    // Esperar con timeout
                    var cts = new CancellationTokenSource(TimeSpan.FromMinutes(_settings.TimeoutMinutes));
                    try
                    {
                        await process.WaitForExitAsync(cts.Token);
                    }
                    catch (OperationCanceledException)
                    {
                        LogConTimestamp("⚠️ Timeout excedido. Matando proceso...");
                        process.Kill();
                        throw new TimeoutException($"El script excedió el tiempo límite de {_settings.TimeoutMinutes} minutos.");
                    }

                    if (process.ExitCode != 0)
                    {
                        LogConTimestamp($"⚠️ Script terminó con error (ExitCode: {process.ExitCode})");
                        if (_settings.EnableDetailedLogging)
                        {
                            LogConTimestamp($"STDERR: {error}");
                        }
                    }
                    else
                    {
                        LogConTimestamp("Script de PowerShell finalizado correctamente.");
                        if (_settings.EnableDetailedLogging)
                        {
                            LogConTimestamp($"STDOUT: {output}");
                        }
                    }
                }

                // 3. Procesar resultados
                if (File.Exists(resultsFile))
                {
                    LogConTimestamp($"Leyendo resultados de: {resultsFile}");
                    string jsonContent = await File.ReadAllTextAsync(resultsFile, stoppingToken);

                    // Validar si el JSON es válido (básico)
                    try
                    {
                        using (JsonDocument.Parse(jsonContent)) { }
                    }
                    catch (JsonException)
                    {
                        throw new Exception("El archivo scan_results.json no contiene un JSON válido.");
                    }

                    // 4. Enviar a API
                    await EnviarResultadosApi(jsonContent, stoppingToken);
                }
                else
                {
                    LogConTimestamp("⚠️ No se generó el archivo scan_results.json");
                }

            }
            catch (Exception ex)
            {
                LogConTimestamp($"❌ Error en ciclo de escaneo: {ex.Message}");
                if (_settings.EnableDetailedLogging)
                {
                    LogConTimestamp(ex.StackTrace);
                }
            }
            finally
            {
                stopwatch.Stop();
                LogConTimestamp($"=== Ciclo finalizado en {stopwatch.Elapsed.TotalSeconds:F1} segundos ===");
            }
        }

        private async Task EnviarResultadosApi(string jsonContent, CancellationToken token)
        {
            if (string.IsNullOrWhiteSpace(_settings.ApiUrl))
            {
                LogConTimestamp("⚠️ URL de API no configurada. Omitiendo envío.");
                return;
            }

            try
            {
                LogConTimestamp($"Enviando datos a API: {_settings.ApiUrl}");
                var client = _httpClientFactory.CreateClient();
                
                var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");
                var response = await client.PostAsync(_settings.ApiUrl, content, token);

                if (response.IsSuccessStatusCode)
                {
                    LogConTimestamp("✅ Datos enviados exitosamente (200 OK).");
                }
                else
                {
                    LogConTimestamp($"❌ Error al enviar a API. Status: {response.StatusCode}");
                    string responseBody = await response.Content.ReadAsStringAsync(token);
                    if (_settings.EnableDetailedLogging)
                    {
                        LogConTimestamp($"Respuesta API: {responseBody}");
                    }
                }
            }
            catch (Exception ex)
            {
                LogConTimestamp($"❌ Excepción de red al enviar a API: {ex.Message}");
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
                string logEntry = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {mensaje}";
                
                // Escribir a consola (visible si se corre como app de consola)
                Console.WriteLine(logEntry);

                // Escribir a archivo
                lock (this)
                {
                    File.AppendAllText(_logFilePath, logEntry + Environment.NewLine);
                }
            }
            catch { /* Ignorar errores de logging para no tumbar el servicio */ }
        }
    }
}
