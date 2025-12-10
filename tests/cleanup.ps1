if (Test-Path "config.ps1") { Remove-Item "config.ps1" }
if (Test-Path "tests\config.ps1") { Remove-Item "tests\config.ps1" }
Write-Host "Cleanup complete."
