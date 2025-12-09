using System;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.ServiceProcess;

namespace NetworkScanner.UI
{
    public partial class MainWindow : Window
    {
        private readonly ScanController _scanController;
        private readonly MonitorController _monitorController;
        private System.Windows.Forms.NotifyIcon? _notifyIcon;
        private const string AppSettingsFile = "appsettings.json";

        private bool _forceClose = false;

        public MainWindow()
        {
            InitializeComponent();
            
            _scanController = new ScanController();
            _scanController.OnProgressUpdated += Controller_OnProgressUpdated;
            _scanController.OnScanCompleted += Controller_OnScanCompleted;

            _monitorController = new MonitorController();
            _monitorController.OnMetricsUpdated += Monitor_OnMetricsUpdated;

            InitializeTrayIcon();
            LoadSettings();
            UpdateUIState();
        }

        private void InitializeTrayIcon()
        {
            _notifyIcon = new System.Windows.Forms.NotifyIcon
            {
                Icon = new System.Drawing.Icon("app_icon.ico"), // Debe coincidir con el recurso
                Visible = false,
                Text = "Network Scanner & Monitor"
            };

            var contextMenu = new System.Windows.Forms.ContextMenuStrip();
            contextMenu.Items.Add("Ver Panel", null, (s, e) => ShowWindow());
            contextMenu.Items.Add("-");
            contextMenu.Items.Add("▶️ Iniciar Servicio", null, (s, e) => ControlService(ServiceControllerStatus.Stopped));
            contextMenu.Items.Add("⏹️ Detener Servicio", null, (s, e) => ControlService(ServiceControllerStatus.Running));
            contextMenu.Items.Add("-");
            contextMenu.Items.Add("Salir", null, (s, e) => ExitApplication());
            _notifyIcon.ContextMenuStrip = contextMenu;
            _notifyIcon.DoubleClick += (s, e) => ShowWindow();
        }

        private void ShowWindow()
        {
            Show();
            WindowState = WindowState.Normal;
            _notifyIcon!.Visible = false;
        }

        private void ExitApplication()
        {
            _forceClose = true;
            _monitorController.StopMonitoring();
            _notifyIcon?.Dispose();
            Close();
        }

        private void Window_Closing(object sender, System.ComponentModel.CancelEventArgs e)
        {
            if (!_forceClose && RbMonitor.IsChecked == true && _monitorController.IsMonitoring)
            {
                e.Cancel = true;
                Hide();
                _notifyIcon!.Visible = true;
                _notifyIcon.ShowBalloonTip(3000, "Monitoreo Activo", "La aplicación sigue ejecutándose en segundo plano.", System.Windows.Forms.ToolTipIcon.Info);
            }
            else
            {
                _monitorController.StopMonitoring();
                _notifyIcon?.Dispose();
            }
        }

        private void Window_StateChanged(object sender, EventArgs e)
        {
            if (WindowState == WindowState.Minimized && RbMonitor.IsChecked == true)
            {
                Hide();
                _notifyIcon!.Visible = true;
            }
        }

        private void Mode_Checked(object sender, RoutedEventArgs e)
        {
            UpdateUIState();
        }

        private void UpdateUIState()
        {
            if (RbMonitor == null || GroupScanConfig == null) return; // Inicialización

            if (RbMonitor.IsChecked == true)
            {
                // Modo Monitor
                GroupScanConfig.Visibility = Visibility.Collapsed;
                GroupMonitorConfig.Visibility = Visibility.Visible;
                PanelScanner.Visibility = Visibility.Collapsed;
                PanelMonitor.Visibility = Visibility.Visible;
                
                BtnAction.Content = _monitorController.IsMonitoring ? "DETENER MONITOREO" : "INICIAR MONITOREO";
                BtnAction.Background = _monitorController.IsMonitoring ? System.Windows.Media.Brushes.Firebrick : System.Windows.Media.Brushes.RoyalBlue;
                
                // Cargar info estática
                var info = SystemMetrics.GetSystemInfo();
                LblHostname.Text = info.Hostname;
                LblOS.Text = info.OS;
                LblIP.Text = info.IP;
            }
            else
            {
                // Modo Escaneo
                GroupScanConfig.Visibility = Visibility.Visible;
                GroupMonitorConfig.Visibility = Visibility.Collapsed;
                PanelScanner.Visibility = Visibility.Visible;
                PanelMonitor.Visibility = Visibility.Collapsed;
                
                BtnAction.Content = "INICIAR ESCANEO";
                BtnAction.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(46, 125, 50)); // Green
            }
        }

        private void BtnAction_Click(object sender, RoutedEventArgs e)
        {
            if (RbManual.IsChecked == true)
            {
                StartScan();
            }
            else
            {
                ToggleMonitor();
            }
        }

        // --- LÓGICA DE ESCANEO ---
        private async void StartScan()
        {
            string ipStart = TxtIpStart.Text.Trim();
            string ipEnd = TxtIpEnd.Text.Trim();

            BtnAction.IsEnabled = false;
            BtnAction.Content = "ESCANEANDO...";
            ScanProgress.Value = 0;
            ProgressPercentage.Text = "0%";
            StatusText.Text = "Iniciando escaneo...";
            TxtResultLog.Text = "";
            SaveSettings(ipStart, ipEnd); // Guardamos IP de inicio y fin como referencia

            try
            {
                // TODO: Pasar start/end al controller
                // Por ahora pasamos start como "subnet" para compatibilidad, 
                // ScanController necesita update para start/end
                string subnetPrefix = ipStart.Substring(0, ipStart.LastIndexOf('.') + 1); 
                await _scanController.StartScanAsync(subnetPrefix, ipStart, ipEnd, true);
            }
            catch (Exception ex)
            {
                StatusText.Text = "Error";
                TxtResultLog.Text = ex.Message;
                BtnAction.IsEnabled = true;
                BtnAction.Content = "INICIAR ESCANEO";
            }
        }

        private void Controller_OnProgressUpdated(ScanProgress progress)
        {
            Dispatcher.Invoke(() =>
            {
                ScanProgress.Value = progress.Percentage;
                ProgressPercentage.Text = $"{progress.Percentage}%";
                DetailText.Text = $"{progress.Current} / {progress.Total}";
                StatusText.Text = $"Escaneando {progress.CurrentIP}...";
            });
        }

        private void Controller_OnScanCompleted()
        {
            Dispatcher.Invoke(() =>
            {
                BtnAction.IsEnabled = true;
                BtnAction.Content = "INICIAR ESCANEO";
                StatusText.Text = "Completado";
                ScanProgress.Value = 100;
                ProgressPercentage.Text = "100%";
                TxtResultLog.Text = $"Escaneo finalizado a las {DateTime.Now}";
            });
        }

        // --- LÓGICA DE MONITOREO ---
        private void ToggleMonitor()
        {
            if (_monitorController.IsMonitoring)
            {
                _monitorController.StopMonitoring();
                LblAgentStatus.Text = "Inactivo";
                LblAgentStatus.Foreground = System.Windows.Media.Brushes.Red;
            }
            else
            {
                _monitorController.StartMonitoring();
                LblAgentStatus.Text = "Activo (Enviando métricas)";
                LblAgentStatus.Foreground = System.Windows.Media.Brushes.Green;
                
                // Sugerencia de minimizar
                // MessageBox.Show("El agente se está ejecutando. Puedes cerrar la ventana para minimizarlo.", "Agente Activo");
            }
            UpdateUIState();
        }

        private void Monitor_OnMetricsUpdated(ClientMetrics metrics)
        {
            Dispatcher.Invoke(() =>
            {
                ValCpu.Text = $"{metrics.CpuUsage}%";
                ValRam.Text = $"{Math.Round(metrics.RamAvailableMb)} MB";
                
                double diskPct = 0;
                if (metrics.DiskTotalGb > 0)
                    diskPct = ((metrics.DiskTotalGb - metrics.DiskFreeGb) / metrics.DiskTotalGb) * 100;
                
                PbDisk.Value = diskPct;
                ValDisk.Text = $"{metrics.DiskFreeGb} GB libres de {metrics.DiskTotalGb} GB";
            });
        }

        // --- SISTEMA ---
        private void LoadSettings()
        {
            try
            {
                if (File.Exists(AppSettingsFile))
                {
                    string json = File.ReadAllText(AppSettingsFile);
                    using (JsonDocument doc = JsonDocument.Parse(json))
                    {
                        if (doc.RootElement.TryGetProperty("ScannerSettings", out var settings))
                        {
                            if (settings.TryGetProperty("SubnetPrefix", out var subnet))
                            {
                                // Trivial restore
                                TxtIpStart.Text = subnet.GetString() + "1";
                                TxtIpEnd.Text = subnet.GetString() + "254";
                            }
                        }
                    }
                }
            }
            catch { }
        }

        private void SaveSettings(string ipStart, string ipEnd)
        {
            try
            {
                string prefix = ipStart.Substring(0, ipStart.LastIndexOf('.') + 1);
                var simpleConfig = new 
                { 
                    ScannerSettings = new 
                    { 
                        SubnetPrefix = prefix,
                        StartIP = ipStart,
                        EndIP = ipEnd
                    } 
                };
                string json = JsonSerializer.Serialize(simpleConfig, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(AppSettingsFile, json);
            }
            catch { }
        }
        private void ControlService(ServiceControllerStatus currentStatus)
        {
            const string serviceName = "NetworkScannerService";
            try
            {
                using (var sc = new ServiceController(serviceName))
                {
                    if (currentStatus == ServiceControllerStatus.Stopped)
                    {
                        sc.Start();
                        _notifyIcon?.ShowBalloonTip(3000, "Network Scanner", "Iniciando servicio...", System.Windows.Forms.ToolTipIcon.Info);
                    }
                    else
                    {
                        sc.Stop();
                        _notifyIcon?.ShowBalloonTip(3000, "Network Scanner", "Deteniendo servicio...", System.Windows.Forms.ToolTipIcon.Info);
                    }
                }
            }
            catch (Exception ex)
            {
                System.Windows.Forms.MessageBox.Show($"Error al controlar servicio:\n{ex.Message}\nRequiere permisos de Admin.", "Error", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
            }
        }
    }
}
