# E2E Verification Script
# Checks static components and simulates logic where possible

$ErrorActionPreference = "Continue"
$PkgDir = "d:\GITHUB\escaner-red\dist\NetworkScanner_Package"
$AgentScript = "$PkgDir\Agent\NetworkScanner.ps1"

Write-Host "============================" -ForegroundColor Cyan
Write-Host " STARTING E2E VERIFICATION" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

# 1. FILE STRUCTURE CHECK
Write-Host "`n[1] Checking Build Output Structure..." -ForegroundColor Yellow
$Files = @(
    "$PkgDir\Service\NetworkScanner.Service.exe",
    "$PkgDir\Agent\NetworkScanner.ps1",
    "$PkgDir\UI\NetworkScanner.UI.exe",
    "$PkgDir\Database\init_database.sql"
)

foreach ($File in $Files) {
    if (Test-Path $File) {
        Write-Host "  [OK] Found: $(Split-Path $File -Leaf)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Missing: $File" -ForegroundColor Red
    }
}

# 2. AGENT SYNTAX CHECK
Write-Host "`n[2] Verifying Agent Syntax..." -ForegroundColor Yellow
if (Test-Path $AgentScript) {
    $Syntax = Get-Command "d:\GITHUB\escaner-red\agent\NetworkScanner.ps1" -Syntax -ErrorAction SilentlyContinue
    if ($?) {
        Write-Host "  [OK] Agent syntax is valid." -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Agent syntax error detected." -ForegroundColor Red
    }
} else {
     Write-Host "  [SKIP] Agent script not found in dist." -ForegroundColor Gray
}

# 3. API CONNECTIVITY SIMULATION
Write-Host "`n[3] Testing API Endpoint (Dry Run)..." -ForegroundColor Yellow
$ApiUrl = "https://dsantana.fimaz.uas.edu.mx/lisi3309/server/api/receive.php"
try {
    $Request = Invoke-WebRequest -Uri $ApiUrl -Method Options -TimeoutSec 5
    if ($Request.StatusCode -eq 200) {
        Write-Host "  [OK] API is reachable (CORS Preflight OK)." -ForegroundColor Green
    } else {
        Write-Host "  [WARN] API returned incorrect status: $($Request.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [FAIL] API Unreachable: $_" -ForegroundColor Red
}

Write-Host "`n[DONE] Verification Complete." -ForegroundColor Cyan
