using System;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Media;

namespace NetworkScanner.UI
{
    public partial class MainWindow : Window
    {
        private readonly ScanController _controller;
        private const string AppSettingsFile = "appsettings.json";

        public MainWindow()
        {
            InitializeComponent();
            _controller = new ScanController();
            
            // Suscribirse a eventos
            _controller.OnProgressUpdated += Controller_OnProgressUpdated;
            _controller.OnScanCompleted += Controller_OnScanCompleted;

            LoadSettings();
        }

        private void LoadSettings()
        {
            try
            {
                // Intentar cargar subnet guardada
                if (File.Exists(AppSettingsFile))
                {
                    string json = File.ReadAllText(AppSettingsFile);
                    using (JsonDocument doc = JsonDocument.Parse(json))
                    {
                        if (doc.RootElement.TryGetProperty("ScannerSettings", out var settings))
                        {
                            if (settings.TryGetProperty("SubnetPrefix", out var subnet))
                            {
                                TxtSubnet.Text = subnet.GetString();
                            }
                        }
                    }
                }
            }
            catch { /* Ignorar errores de carga */ }
        }

        private void SaveSettings(string subnet)
        {
            try
            {
                // Guardar configuración simple persistente
                var simpleConfig = new 
                { 
                    ScannerSettings = new { SubnetPrefix = subnet } 
                };
                
                string json = JsonSerializer.Serialize(simpleConfig, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(AppSettingsFile, json);
            }
            catch { /* Ignorar */ }
        }

        private async void BtnScan_Click(object sender, RoutedEventArgs e)
        {
            string subnet = TxtSubnet.Text.Trim();
            
            // Validación básica
            if (string.IsNullOrWhiteSpace(subnet) || subnet.Split('.').Length < 3)
            {
                MessageBox.Show("Por favor ingrese un prefijo de subred válido (ej: 192.168.100.)", "Error de Validación", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            // Preparar UI
            BtnScan.IsEnabled = false;
            BtnScan.Content = "ESCANEANDO...";
            ScanProgress.Value = 0;
            ProgressPercentage.Text = "0%";
            StatusText.Text = "Iniciando escaneo...";
            StatusText.Foreground = Brushes.Orange;
            ResultSummary.Text = "Escaneo en progreso. Por favor espere...";
            
            // Guardar configuración
            SaveSettings(subnet);

            // Determinar modo
            bool isManual = RbManual.IsChecked == true;

            try
            {
                await _controller.StartScanAsync(subnet, isManual);
            }
            catch (Exception ex)
            {
                StatusText.Text = "Error al iniciar";
                StatusText.Foreground = Brushes.Red;
                ResultSummary.Text = $"Ocurrió un error: {ex.Message}";
                BtnScan.IsEnabled = true;
                BtnScan.Content = "INICIAR ESCANEO";
            }
        }

        private void Controller_OnProgressUpdated(ScanProgress progress)
        {
            // Actualizar UI en el hilo principal
            Dispatcher.Invoke(() =>
            {
                ScanProgress.Value = progress.Percentage;
                ProgressPercentage.Text = $"{progress.Percentage}%";
                DetailText.Text = $"{progress.Current} / {progress.Total} IPs";
                
                if (!string.IsNullOrEmpty(progress.CurrentIP))
                {
                    StatusText.Text = $"Escaneando {progress.CurrentIP}...";
                }
            });
        }

        private void Controller_OnScanCompleted()
        {
            Dispatcher.Invoke(() =>
            {
                BtnScan.IsEnabled = true;
                BtnScan.Content = "INICIAR ESCANEO";
                
                StatusText.Text = "Escaneo Completado";
                StatusText.Foreground = Brushes.Green;
                ScanProgress.Value = 100;
                ProgressPercentage.Text = "100%";
                
                ResultSummary.Text = $"Escaneo finalizado exitosamente.\n\n" +
                                     $"Fecha: {DateTime.Now}\n" +
                                     $"Modo: {(RbManual.IsChecked == true ? "Manual" : "Monitoreo")}\n" +
                                     $"Los resultados han sido procesados internamente.";
            });
        }
    }
}
