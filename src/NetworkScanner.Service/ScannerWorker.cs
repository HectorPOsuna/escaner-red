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
        private readonly string _heartbeatFile;

        // Resilience tracking
        private int _consecutiveErrors = 0;
        private const int MAX_CONSECUTIVE_ERRORS = 10;
        private int _apiFailures = 0;
        private const int CIRCUIT_BREAKER_THRESHOLD = 5;
        private DateTime _circuitBreakerOpenedAt = DateTime.MinValue;
        private readonly TimeSpan _circuitBreakerTimeout = TimeSpan.FromMinutes(5);

        public ScannerWorker(
            ILogger<ScannerWorker> logger,
            IOptions<ScannerSettings> settings,
            IHttpClientFactory httpClientFactory)
        {
            _logger = logger;
            _settings = settings.Value;
            _httpClientFactory = httpClientFactory;

            // Usar ProgramData (Standard Windows)
            string commonData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
            _logDirectory = Path.Combine(commonData, "NetworkScanner", "Logs");
            
            if (!Directory.Exists(_logDirectory))
            {
                Directory.CreateDirectory(_logDirectory);
            }

            _logFilePath = Path.Combine(_logDirectory, $"service_{DateTime.Now:yyyyMMdd}.log");
            _heartbeatFile = Path.Combine(_logDirectory, "heartbeat.txt");
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            LogConTimestamp($"Servicio Iniciado. Intervalo: {_settings.IntervalMinutes} min. Escaneo local activo.");
            _logger.LogInformation("NetworkScannerService iniciado.");
            LogToEventViewer("Servicio iniciado correctamente", EventLogEntryType.Information);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    // Actualizar heartbeat
                    UpdateHeartbeat();

                    // Ejecutar ciclo
                    await EjecutarCicloEscaneo(stoppingToken);

                    // Reset error counter en éxito
                    _consecutiveErrors = 0;

                    // Esperar intervalo normal
                    await Task.Delay(TimeSpan.FromMinutes(_settings.IntervalMinutes), stoppingToken);
                }
                catch (TaskCanceledException)
                {
                    LogConTimestamp("Servicio cancelado por token de detención.");
                    break;
                }
                catch (Exception ex)
                {
                    _consecutiveErrors++;
                    LogConTimestamp($"ERROR en ciclo #{_consecutiveErrors}: {ex.Message}");
                    _logger.LogError(ex, "Error en el ciclo del servicio");

                    // Prevenir bucles infinitos
                    if (_consecutiveErrors >= MAX_CONSECUTIVE_ERRORS)
                    {
                        LogConTimestamp($"ALERTA: {MAX_CONSECUTIVE_ERRORS} errores consecutivos. Esperando 30 minutos antes de continuar.");
                        LogToEventViewer($"Demasiados errores consecutivos ({_consecutiveErrors}). Entrando en modo de espera extendida.", EventLogEntryType.Warning);
                        
                        await Task.Delay(TimeSpan.FromMinutes(30), stoppingToken);
                        _consecutiveErrors = 0; // Reset después de espera larga
                    }
                    else
                    {
                        // Exponential backoff
                        var backoff = CalculateBackoff(_consecutiveErrors);
                        LogConTimestamp($"Esperando {backoff.TotalSeconds}s antes del siguiente intento (backoff)...");
                        await Task.Delay(backoff, stoppingToken);
                    }
                }
            }

            LogConTimestamp("Servicio finalizando normalmente.");
        }

        private async Task EjecutarCicloEscaneo(CancellationToken stoppingToken)
        {
            LogConTimestamp("--- Iniciando ciclo de escaneo local (Automático) ---");
            
            try
            {
                var scanner = new LocalHostScanner();
                var results = await scanner.ScanAsync();
                
                // Formatear para compatibilidad con el backend ( legacy format 'Devices' array )
                // El backend espera: { "Devices": [ { "IP": "...", "MAC": "...", "Hostname": "...", "OS": "...", "OpenPorts": [...] } ] }
                
                var primaryInterface = results.network_interfaces.FirstOrDefault(ni => ni.is_primary) 
                                      ?? results.network_interfaces.FirstOrDefault(ni => ni.ip_address != "N/A" && ni.ip_address != "127.0.0.1");

                var legacyPayload = new
                {
                    Devices = new[]
                    {
                        new
                        {
                            IP = primaryInterface?.ip_address ?? "127.0.0.1",
                            MAC = primaryInterface?.mac_address ?? "",
                            Hostname = results.host_info.hostname,
                            OS = results.host_info.os_name,
                            OS_Simple = "Windows",
                            TTL = 128,
                            OS_Hints = results.host_info.os_version,
                            Manufacturer = results.host_info.manufacturer,
                            OpenPorts = results.ports_snapshot.Select(p => new { 
                                port = p.port, 
                                protocol = p.type // Enviamos el tipo (TCP/UDP) como protocolo para el backend
                            }).ToArray()
                        }
                    }
                };

                string json = JsonSerializer.Serialize(legacyPayload, new JsonSerializerOptions { WriteIndented = true });
                
                if (_settings.EnableDetailedLogging)
                {
                    LogConTimestamp($"Escaneo completado. Puertos abiertos detectados: {results.ports_snapshot.Count}");
                }

                await EnviarResultadosApi(json, stoppingToken);
            }
            catch (Exception ex)
            {
                LogConTimestamp($"Error en ciclo de escaneo: {ex.Message}");
                throw;
            }
        }

        private async Task EnviarResultadosApi(string json, CancellationToken token)
        {
            if (string.IsNullOrEmpty(_settings.ApiUrl)) return;

            // Circuit Breaker: verificar si está abierto
            if (IsCircuitBreakerOpen())
            {
                LogConTimestamp("Circuit breaker ABIERTO - Saltando envío a API");
                return;
            }

            try
            {
                var client = _httpClientFactory.CreateClient();
                client.Timeout = TimeSpan.FromSeconds(30);

                var content = new StringContent(json, Encoding.UTF8, "application/json");
                var response = await client.PostAsync(_settings.ApiUrl, content, token);

                if (response.IsSuccessStatusCode)
                {
                    LogConTimestamp("Datos enviados a API exitosamente.");
                    _apiFailures = 0; // Reset en éxito
                }
                else
                {
                    _apiFailures++;
                    LogConTimestamp($"API Error {response.StatusCode} (Fallo #{_apiFailures})");
                    
                    if (_apiFailures >= CIRCUIT_BREAKER_THRESHOLD)
                    {
                        _circuitBreakerOpenedAt = DateTime.Now;
                        LogConTimestamp($"Circuit breaker ABIERTO después de {_apiFailures} fallos");
                        LogToEventViewer($"Circuit breaker activado para API después de {_apiFailures} fallos consecutivos", EventLogEntryType.Warning);
                    }
                }
            }
            catch (Exception ex)
            {
                _apiFailures++;
                LogConTimestamp($"Error envío API: {ex.Message} (Fallo #{_apiFailures})");
                
                if (_apiFailures >= CIRCUIT_BREAKER_THRESHOLD)
                {
                    _circuitBreakerOpenedAt = DateTime.Now;
                    LogConTimestamp($"Circuit breaker ABIERTO después de {_apiFailures} fallos");
                    LogToEventViewer($"Circuit breaker activado para API después de {_apiFailures} fallos consecutivos", EventLogEntryType.Warning);
                }
            }
        }

        private bool IsCircuitBreakerOpen()
        {
            if (_apiFailures < CIRCUIT_BREAKER_THRESHOLD) return false;

            var elapsed = DateTime.Now - _circuitBreakerOpenedAt;
            if (elapsed > _circuitBreakerTimeout)
            {
                // Cerrar circuit breaker y reintentar
                LogConTimestamp("Circuit breaker CERRADO - Reintentando API");
                _apiFailures = 0;
                return false;
            }

            return true;
        }

        private TimeSpan CalculateBackoff(int errorCount)
        {
            // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, max 60s
            var seconds = Math.Min(Math.Pow(2, errorCount), 60);
            return TimeSpan.FromSeconds(seconds);
        }

        private void UpdateHeartbeat()
        {
            try
            {
                File.WriteAllText(_heartbeatFile, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            }
            catch
            {
                // No crítico si falla
            }
        }

        public override async Task StopAsync(CancellationToken stoppingToken)
        {
            LogConTimestamp("Servicio DETENIÉNDOSE...");
            LogToEventViewer("Servicio detenido", EventLogEntryType.Information);
            await base.StopAsync(stoppingToken);
        }

        private void LogConTimestamp(string mensaje)
        {
            try
            {
                string entry = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {mensaje}";
                
                lock (this)
                {
                    File.AppendAllText(_logFilePath, entry + Environment.NewLine);
                }
            }
            catch { }
        }

        private void LogToEventViewer(string message, EventLogEntryType type)
        {
            try
            {
                var eventLog = new EventLog("Application")
                {
                    Source = "NetworkScannerService"
                };
                eventLog.WriteEntry(message, type, type == EventLogEntryType.Error ? 1001 : 1000);
            }
            catch
            {
                // Si falla Event Viewer, no es crítico
            }
        }
    }
}
