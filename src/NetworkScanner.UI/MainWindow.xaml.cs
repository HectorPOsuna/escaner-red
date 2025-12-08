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
            
            // Use PathResolver to find appsettings.json
            _appSettingsPath = PathResolver.GetServiceConfigPath() ?? "appsettings.json";

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
                string json = File.Exists(_appSettingsPath) ? File.ReadAllText(_appSettingsPath) : "{}";
                
                var newSettings = new ScannerSettings
                {
                    IntervalMinutes = int.Parse(TxtInterval.Text),
                    ApiUrl = TxtApiUrl.Text,
                    ScriptPath = TxtScriptPath.Text
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
            // Use PathResolver for logs directory
            string logDir = PathResolver.GetLogsDirectory();
            if (Directory.Exists(logDir))
            {
                var files = Directory.GetFiles(logDir, "*.log");
                if (files.Length > 0)
                {
                    Array.Sort(files);
                    string lastLog = files[files.Length - 1];
                    try
                    {
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
                // Use centralized path resolver
                string? serviceExe = PathResolver.GetServiceExecutablePath();
                
                if (serviceExe == null)
                {
                    MessageBox.Show(
                        "No se encuentra el ejecutable del servicio.\n\n" +
                        "Ubicaciones buscadas:\n" +
                        "- C:\\Program Files\\NetworkScanner\\Service\\NetworkScanner.Service.exe\n" +
                        "- Directorio de la UI\n" +
                        "- Directorio padre\\Service\\\n" +
                        "- Entorno de desarrollo\n\n" +
                        "Asegúrate de que el servicio esté correctamente instalado.",
                        "Error",
                        MessageBoxButton.OK,
                        MessageBoxImage.Error);
                    return;
                }

                ServiceManager.InstallService(serviceExe);
                MessageBox.Show(
                    $"Servicio instalado correctamente.\n\nRuta: {serviceExe}",
                    "Éxito",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
                UpdateStatus();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error de instalación: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
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