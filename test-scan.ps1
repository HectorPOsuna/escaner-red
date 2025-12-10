# test-scan.ps1 - Script de prueba simple
param(
    [string]$Subnet = "192.168.1."
)

Write-Host "=== TEST ESCANEO SIMPLIFICADO ===" -ForegroundColor Cyan

# Probar solo 3 IPs
$testIPs = @(
    "${Subnet}1",
    "${Subnet}100",
    "${Subnet}254"
)

foreach ($ip in $testIPs) {
    Write-Host "`nProbando $ip..." -ForegroundColor Yellow
    
    # Ping simple
    $alive = Test-Connection -ComputerName $ip -Count 1 -Quiet
    Write-Host "  Ping: $(if($alive){'ACTIVO' -f 'Green'}else{'INACTIVO' -f 'Red'})" -ForegroundColor $(if($alive){"Green"}else{"Red"})
    
    if ($alive) {
        # Intentar resolver hostname
        try {
            $hostname = [System.Net.Dns]::GetHostEntry($ip).HostName
            Write-Host "  Hostname: $hostname" -ForegroundColor Cyan
        } catch {
            Write-Host "  Hostname: No disponible" -ForegroundColor Gray
        }
        
        # Intentar obtener MAC
        try {
            $arp = arp -a $ip 2>$null
            if ($arp -match '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})') {
                Write-Host "  MAC: $($Matches[0])" -ForegroundColor Cyan
            } else {
                Write-Host "  MAC: No detectada" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  MAC: Error" -ForegroundColor Red
        }
        
        # Probar puertos comunes
        $testPorts = @(80, 443, 22, 3389)
        foreach ($port in $testPorts) {
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $result = $tcp.BeginConnect($ip, $port, $null, $null)
                $wait = $result.AsyncWaitHandle.WaitOne(500, $false)
                $tcp.Close()
                
                if ($wait) {
                    Write-Host "  Puerto $port : ABIERTO" -ForegroundColor Green
                } else {
                    Write-Host "  Puerto $port : cerrado" -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "  Puerto $port : error" -ForegroundColor DarkGray
            }
        }
    }
}

Write-Host "`n=== TEST COMPLETADO ===" -ForegroundColor Cyan