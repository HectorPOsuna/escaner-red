using System;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using NetworkScanner.Shared;

namespace NetworkScanner.UI
{
    public partial class MainWindow : Window
    {
        private DispatcherTimer _timer;
        private string _appSettingsPath = "appsettings.json";

        public MainWindow()
        {
            InitializeComponent();
            
            // Buscar appsettings.json
            // 1. En directorio actual (desarrollo)
            // 2. En directorio del servicio (producción, si están juntos)
            // Para demo asumimos que se copian juntos
            if (!File.Exists(_appSettingsPath))
            {
               // Intentar buscar en ../NetworkScanner.Service/ si estamos en debug
               string devPath = @"..\..\..\..\NetworkScanner.Service\appsettings.json";
               if (File.Exists(devPath)) _appSettingsPath = devPath;
            }

            LoadConfig();
            UpdateStatus();

            _timer = new DispatcherTimer();
            _timer.Interval = TimeSpan.FromSeconds(2);
            _timer.Tick += (s, e) => UpdateStatus();
            _timer.Start();

            // Cargar logs
            LoadLogs();
        }

        private void UpdateStatus()
        {
            string status = ServiceManager.GetStatus();
            StatusText.Text = status;

            switch (status)
            {
                case "Running":
                    StatusIndicator.Fill = Brushes.Green;
                    BtnStart.IsEnabled = false;
                    BtnStop.IsEnabled = true;
                    BtnInstall.IsEnabled = false;
                    BtnUninstall.IsEnabled = false; // Detener primero
                    break;
                case "Stopped":
                    StatusIndicator.Fill = Brushes.Red;
                    BtnStart.IsEnabled = true;
                    BtnStop.IsEnabled = false;
                    BtnInstall.IsEnabled = false;
                    BtnUninstall.IsEnabled = true;
                    break;
                case "No Instalado":
                    StatusIndicator.Fill = Brushes.Gray;
                    BtnStart.IsEnabled = false;
                    BtnStop.IsEnabled = false;
                    BtnInstall.IsEnabled = true;
                    BtnUninstall.IsEnabled = false;
                    break;
                default:
                    StatusIndicator.Fill = Brushes.Yellow;
                    break;
            }
        }

        private void LoadConfig()
        {
            if (File.Exists(_appSettingsPath))
            {
                try
                {
                    string json = File.ReadAllText(_appSettingsPath);
                    // Parseo simple para demo, idealmente usar ScannerSettings
                    using (JsonDocument doc = JsonDocument.Parse(json))
                    {
                        var settings = doc.RootElement.GetProperty("ScannerSettings");
                        TxtInterval.Text = settings.GetProperty("IntervalMinutes").GetInt32().ToString();
                        TxtApiUrl.Text = settings.GetProperty("ApiUrl").GetString();
                        TxtScriptPath.Text = settings.GetProperty("ScriptPath").GetString();
                    }
                }
                catch { }
            }
        }

        private void BtnSaveConfig_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Leer y actualizar solo ScannerSettings
                // Esto es simplificado. En prod usar serialización tipada completa.
                string json = File.Exists(_appSettingsPath) ? File.ReadAllText(_appSettingsPath) : "{}";
                
                // Hack rápido para demo: reemplazar valores a lo bruto o reconstruir JSON
                // Mejor: Reconstruir usando el objeto
                var newSettings = new ScannerSettings
                {
                    IntervalMinutes = int.Parse(TxtInterval.Text),
                    ApiUrl = TxtApiUrl.Text,
                    ScriptPath = TxtScriptPath.Text
                    // Otros defaults
                };

                var root = new { 
                    ScannerSettings = newSettings,
                    Logging = new { LogLevel = new { Default = "Information" } } 
                };

                File.WriteAllText(_appSettingsPath, JsonSerializer.Serialize(root, new JsonSerializerOptions { WriteIndented = true }));
                MessageBox.Show("Configuración guardada. Reinicia el servicio para aplicar cambios.", "Éxito");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error al guardar: {ex.Message}", "Error");
            }
        }

        private void LoadLogs()
        {
            // Leer último log de C:\Logs\NetworkScanner
            string logDir = @"C:\Logs\NetworkScanner";
            if (Directory.Exists(logDir))
            {
                var files = Directory.GetFiles(logDir, "*.log");
                if (files.Length > 0)
                {
                    Array.Sort(files);
                    string lastLog = files[files.Length - 1];
                    try
                    {
                         // Leer últimas líneas
                         string[] lines = File.ReadAllLines(lastLog);
                         LogOutput.Text = string.Join(Environment.NewLine, lines);
                         LogOutput.ScrollToEnd();
                    }
                    catch { }
                }
            }
        }

        private void BtnInstall_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Asumimos que el EXE del servicio se llama "NetworkScanner.Service.exe" 
                // y está en la misma carpeta que la UI
                string currentDir = AppDomain.CurrentDomain.BaseDirectory;
                string serviceExe = Path.Combine(currentDir, "NetworkScanner.Service.exe");
                
                // Si estamos en debug, buscar en la carpeta del otro proyecto
                if (!File.Exists(serviceExe))
                {
                     // Try debug path relative check
                     string debugPath = Path.GetFullPath(Path.Combine(currentDir, @"..\..\..\..\NetworkScanner.Service\bin\Debug\net10.0\NetworkScanner.Service.exe"));
                     // Nota: ajusta "net10.0" según tu sdk 
                     if (File.Exists(debugPath)) serviceExe = debugPath;
                }

                if (!File.Exists(serviceExe))
                {
                    MessageBox.Show($"No se encuentra el ejecutable del servicio:\n{serviceExe}", "Error");
                    return;
                }

                ServiceManager.InstallService(serviceExe);
                MessageBox.Show("Servicio instalado correctamente.", "Éxito");
                UpdateStatus();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error de instalación: {ex.Message}", "Error");
            }
        }

        private void BtnUninstall_Click(object sender, RoutedEventArgs e)
        {
            ServiceManager.UninstallService();
            MessageBox.Show("Comando de desinstalación enviado.", "Info");
        }

        private void BtnStart_Click(object sender, RoutedEventArgs e) { ServiceManager.StartService(); }
        private void BtnStop_Click(object sender, RoutedEventArgs e) { ServiceManager.StopService(); }
    }
}