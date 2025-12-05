using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Timers;

namespace NetworkScannerService
{
    /// <summary>
    /// Worker del servicio que ejecuta el agente de escaneo periódicamente
    /// </summary>
    public class ScannerWorker : BackgroundService
    {
        private readonly ILogger<ScannerWorker> _logger;
        private System.Timers.Timer _timer;
        private readonly string _logDirectory = @"C:\Logs\MiServicio";
        private readonly string _logFilePath;

        // Configuración del intervalo de ejecución (en milisegundos)
        // 5 minutos = 300000 ms
        private const int INTERVALO_EJECUCION_MS = 300000;

        public ScannerWorker(ILogger<ScannerWorker> logger)
        {
            _logger = logger;
            
            // Crear directorio de logs si no existe
            if (!Directory.Exists(_logDirectory))
            {
                Directory.CreateDirectory(_logDirectory);
            }

            _logFilePath = Path.Combine(_logDirectory, $"service_{DateTime.Now:yyyyMMdd}.log");
        }

        /// <summary>
        /// Inicia el servicio y configura el timer
        /// </summary>
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            EscribirLog("Servicio iniciado correctamente");
            _logger.LogInformation("NetworkScannerService iniciado a las: {time}", DateTimeOffset.Now);

            // Configurar el timer
            _timer = new System.Timers.Timer(INTERVALO_EJECUCION_MS);
            _timer.Elapsed += OnTimerElapsed;
            _timer.AutoReset = true;
            _timer.Enabled = true;

            EscribirLog($"Timer configurado con intervalo de {INTERVALO_EJECUCION_MS / 1000} segundos");

            // Ejecutar inmediatamente al iniciar (opcional)
            EjecutarAgente();

            // Mantener el servicio en ejecución
            while (!stoppingToken.IsCancellationRequested)
            {
                await Task.Delay(1000, stoppingToken);
            }
        }

        /// <summary>
        /// Evento que se dispara cuando el timer alcanza el intervalo
        /// </summary>
        private void OnTimerElapsed(object sender, ElapsedEventArgs e)
        {
            try
            {
                EjecutarAgente();
            }
            catch (Exception ex)
            {
                EscribirLog($"ERROR en OnTimerElapsed: {ex.Message}");
                _logger.LogError(ex, "Error en el timer del servicio");
            }
        }

        /// <summary>
        /// Función principal que ejecuta el agente de escaneo
        /// Ejecuta NetworkScanner.ps1 y procesa los resultados
        /// </summary>
        private void EjecutarAgente()
        {
            try
            {
                EscribirLog("=== INICIO DE EJECUCIÓN DEL AGENTE ===");
                _logger.LogInformation("Ejecutando agente de escaneo a las: {time}", DateTimeOffset.Now);

                // Ruta al script PowerShell
                // Ajustar según la ubicación real del servicio
                string scriptPath = Path.Combine(
                    AppDomain.CurrentDomain.BaseDirectory,
                    @"..\agent\NetworkScanner.ps1"
                );

                // Normalizar la ruta
                scriptPath = Path.GetFullPath(scriptPath);

                if (!File.Exists(scriptPath))
                {
                    EscribirLog($"ERROR: No se encontró el script en: {scriptPath}");
                    _logger.LogError("Script PowerShell no encontrado en: {path}", scriptPath);
                    return;
                }

                EscribirLog($"Ejecutando script: {scriptPath}");

                // Configurar el proceso de PowerShell
                var processStartInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = $"-ExecutionPolicy Bypass -NoProfile -File \"{scriptPath}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true,
                    WorkingDirectory = Path.GetDirectoryName(scriptPath)
                };

                using (var process = new System.Diagnostics.Process())
                {
                    process.StartInfo = processStartInfo;

                    // Capturar salida estándar
                    var outputBuilder = new System.Text.StringBuilder();
                    var errorBuilder = new System.Text.StringBuilder();

                    process.OutputDataReceived += (sender, e) =>
                    {
                        if (!string.IsNullOrEmpty(e.Data))
                        {
                            outputBuilder.AppendLine(e.Data);
                            EscribirLog($"[PS] {e.Data}");
                        }
                    };

                    process.ErrorDataReceived += (sender, e) =>
                    {
                        if (!string.IsNullOrEmpty(e.Data))
                        {
                            errorBuilder.AppendLine(e.Data);
                            EscribirLog($"[PS ERROR] {e.Data}");
                        }
                    };

                    // Iniciar el proceso
                    EscribirLog("Iniciando proceso PowerShell...");
                    process.Start();

                    // Comenzar a leer las salidas de forma asíncrona
                    process.BeginOutputReadLine();
                    process.BeginErrorReadLine();

                    // Esperar a que termine (con timeout de 10 minutos)
                    bool finished = process.WaitForExit(600000); // 10 minutos

                    if (!finished)
                    {
                        EscribirLog("ADVERTENCIA: El script excedió el tiempo límite de 10 minutos. Terminando proceso...");
                        process.Kill();
                        _logger.LogWarning("Script PowerShell excedió el tiempo límite");
                    }
                    else
                    {
                        int exitCode = process.ExitCode;
                        EscribirLog($"Script finalizado. Código de salida: {exitCode}");

                        if (exitCode == 0)
                        {
                            EscribirLog("✅ Escaneo completado exitosamente");
                            _logger.LogInformation("Escaneo completado exitosamente");
                        }
                        else
                        {
                            EscribirLog($"⚠️ El script finalizó con código de error: {exitCode}");
                            _logger.LogWarning("Script finalizó con código de error: {code}", exitCode);
                        }

                        // Registrar errores si los hay
                        string errors = errorBuilder.ToString();
                        if (!string.IsNullOrWhiteSpace(errors))
                        {
                            EscribirLog("Errores capturados:");
                            EscribirLog(errors);
                            _logger.LogError("Errores PowerShell: {errors}", errors);
                        }
                    }
                }

                EscribirLog("=== FIN DE EJECUCIÓN DEL AGENTE ===");
            }
            catch (Exception ex)
            {
                EscribirLog($"ERROR CRÍTICO en EjecutarAgente: {ex.Message}");
                EscribirLog($"StackTrace: {ex.StackTrace}");
                _logger.LogError(ex, "Error crítico al ejecutar el agente");
            }
        }

        /// <summary>
        /// Detiene el servicio y limpia recursos
        /// </summary>
        public override async Task StopAsync(CancellationToken stoppingToken)
        {
            EscribirLog("Deteniendo servicio...");
            _logger.LogInformation("NetworkScannerService deteniéndose a las: {time}", DateTimeOffset.Now);

            // Detener el timer
            if (_timer != null)
            {
                _timer.Stop();
                _timer.Dispose();
            }

            EscribirLog("Servicio detenido correctamente");

            await base.StopAsync(stoppingToken);
        }

        /// <summary>
        /// Escribe mensajes en el archivo de log
        /// </summary>
        private void EscribirLog(string mensaje)
        {
            try
            {
                string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
                string lineaLog = $"[{timestamp}] {mensaje}";

                // Escribir en archivo con lock para thread-safety
                lock (this)
                {
                    File.AppendAllText(_logFilePath, lineaLog + Environment.NewLine);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al escribir en el log");
            }
        }

        /// <summary>
        /// Limpia recursos al destruir el objeto
        /// </summary>
        public override void Dispose()
        {
            _timer?.Dispose();
            base.Dispose();
        }
    }
}
