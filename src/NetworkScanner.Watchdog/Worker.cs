using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Diagnostics;
using System.IO;
using System.ServiceProcess;
using System.Threading;
using System.Threading.Tasks;

namespace NetworkScanner.Watchdog
{
    public class WatchdogWorker : BackgroundService
    {
        private readonly ILogger<WatchdogWorker> _logger;
        private const string TARGET_SERVICE_NAME = "NetworkScannerService";
        private const string HEARTBEAT_FILE = @"C:\Logs\NetworkScanner\heartbeat.txt";
        private const string WATCHDOG_LOG_FILE = @"C:\Logs\NetworkScanner\watchdog.log";
        private const int CHECK_INTERVAL_MINUTES = 5;
        private const int HEARTBEAT_TIMEOUT_MINUTES = 10;

        public WatchdogWorker(ILogger<WatchdogWorker> logger)
        {
            _logger = logger;
            EnsureLogDirectory();
        }

        private void EnsureLogDirectory()
        {
            var logDir = Path.GetDirectoryName(WATCHDOG_LOG_FILE);
            if (logDir != null && !Directory.Exists(logDir))
            {
                Directory.CreateDirectory(logDir);
            }
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            LogMessage("Watchdog iniciado. Monitoreando servicio: " + TARGET_SERVICE_NAME);
            _logger.LogInformation("Watchdog service started");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await CheckServiceHealth(stoppingToken);
                    await Task.Delay(TimeSpan.FromMinutes(CHECK_INTERVAL_MINUTES), stoppingToken);
                }
                catch (TaskCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    LogMessage($"ERROR en watchdog: {ex.Message}");
                    _logger.LogError(ex, "Error in watchdog loop");
                    await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
                }
            }

            LogMessage("Watchdog detenido.");
        }

        private async Task CheckServiceHealth(CancellationToken stoppingToken)
        {
            // 1. Verificar si el servicio existe
            if (!ServiceExists(TARGET_SERVICE_NAME))
            {
                LogMessage($"ADVERTENCIA: Servicio {TARGET_SERVICE_NAME} no está instalado.");
                return;
            }

            // 2. Verificar estado del servicio
            using var controller = new ServiceController(TARGET_SERVICE_NAME);
            var status = controller.Status;

            LogMessage($"Estado del servicio: {status}");

            // 3. Si está detenido, intentar iniciar
            if (status == ServiceControllerStatus.Stopped)
            {
                LogMessage("⚠ Servicio DETENIDO. Intentando reiniciar...");
                LogToEventViewer($"Watchdog detectó servicio detenido. Reiniciando {TARGET_SERVICE_NAME}");
                
                try
                {
                    controller.Start();
                    controller.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(30));
                    LogMessage("✓ Servicio reiniciado exitosamente.");
                    LogToEventViewer($"Servicio {TARGET_SERVICE_NAME} reiniciado exitosamente por watchdog");
                }
                catch (Exception ex)
                {
                    LogMessage($"ERROR al reiniciar servicio: {ex.Message}");
                    LogToEventViewer($"Watchdog falló al reiniciar {TARGET_SERVICE_NAME}: {ex.Message}");
                }
                return;
            }

            // 4. Si está corriendo, verificar heartbeat
            if (status == ServiceControllerStatus.Running)
            {
                if (!File.Exists(HEARTBEAT_FILE))
                {
                    LogMessage("ADVERTENCIA: Archivo heartbeat no existe aún.");
                    return;
                }

                try
                {
                    var heartbeatContent = File.ReadAllText(HEARTBEAT_FILE);
                    if (DateTime.TryParse(heartbeatContent, out DateTime lastHeartbeat))
                    {
                        var elapsed = DateTime.Now - lastHeartbeat;
                        LogMessage($"Último heartbeat: {lastHeartbeat:yyyy-MM-dd HH:mm:ss} (hace {elapsed.TotalMinutes:F1} minutos)");

                        if (elapsed.TotalMinutes > HEARTBEAT_TIMEOUT_MINUTES)
                        {
                            LogMessage($"🚨 ALERTA: Heartbeat expirado (>{HEARTBEAT_TIMEOUT_MINUTES} min). Servicio puede estar colgado.");
                            LogToEventViewer($"Watchdog detectó heartbeat expirado en {TARGET_SERVICE_NAME}. Reiniciando servicio.");
                            
                            // Reiniciar servicio
                            try
                            {
                                LogMessage("Deteniendo servicio...");
                                controller.Stop();
                                controller.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30));
                                
                                LogMessage("Iniciando servicio...");
                                controller.Start();
                                controller.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(30));
                                
                                LogMessage("✓ Servicio reiniciado por heartbeat expirado.");
                                LogToEventViewer($"Servicio {TARGET_SERVICE_NAME} reiniciado exitosamente por watchdog (heartbeat expirado)");
                            }
                            catch (Exception ex)
                            {
                                LogMessage($"ERROR al reiniciar servicio: {ex.Message}");
                                LogToEventViewer($"Watchdog falló al reiniciar {TARGET_SERVICE_NAME}: {ex.Message}");
                            }
                        }
                        else
                        {
                            LogMessage("✓ Servicio funcionando correctamente.");
                        }
                    }
                    else
                    {
                        LogMessage("ADVERTENCIA: Formato de heartbeat inválido.");
                    }
                }
                catch (Exception ex)
                {
                    LogMessage($"ERROR al leer heartbeat: {ex.Message}");
                }
            }
        }

        private bool ServiceExists(string serviceName)
        {
            try
            {
                using var controller = new ServiceController(serviceName);
                var _ = controller.Status;
                return true;
            }
            catch
            {
                return false;
            }
        }

        private void LogMessage(string message)
        {
            try
            {
                string entry = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}";
                if (Environment.UserInteractive) Console.WriteLine(entry);
                
                lock (this)
                {
                    File.AppendAllText(WATCHDOG_LOG_FILE, entry + Environment.NewLine);
                }
            }
            catch { }
        }

        private void LogToEventViewer(string message)
        {
            try
            {
                var eventLog = new EventLog("Application")
                {
                    Source = "NetworkScannerWatchdog"
                };
                eventLog.WriteEntry(message, EventLogEntryType.Warning, 2001);
            }
            catch { }
        }
    }
}
