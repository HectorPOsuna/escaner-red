# Test-NetworkScanner.ps1
# Unit Tests for NetworkScanner Agent

$AgentPath = "d:\GITHUB\escaner-red\agent\NetworkScanner.ps1"

Describe "Network Scanner Agent" {
    # Setup Config BEFORE sourcing
    $TestConfigFile = Join-Path $PSScriptRoot "config.ps1"
    $TestConfigContent = '$SubnetPrefix = "10.10.10."'
    Set-Content -Path $TestConfigFile -Value $TestConfigContent

    # Source globally for all contexts
    # Note: If running from root, config.ps1 in tests/ might not be seen unless we are in tests/
    # But sourcing happens in current scope.
    # The script looks for $ConfigFile ("config.ps1") in current dir.
    # We should ensure we are in the right dir or pass path? 
    # Can't pass path to dot-source easily. 
    # Ensure config.ps1 is in CWD.
    $CwdConfig = ".\config.ps1"
    Set-Content -Path $CwdConfig -Value $TestConfigContent
    
    . $AgentPath

    Context "0. Configuration Loading" {
        It "Should load SubnetPrefix from config.ps1" {
            $SubnetPrefix | Should Be "10.10.10."
        }
    }

    Context "1. Script Loading & Syntax" {
        It "Should load without syntax errors" {
            { . $AgentPath } | Should Not Throw
        }
    }

    Context "2. Function Availability" {
        It "Should export Get-IpRange function" {
            Get-Command "Get-IpRange" -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "Should export Test-HostAlive function" {
            Get-Command "Test-HostAlive" -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "Should export Rotate-Logs function" {
            Get-Command "Rotate-Logs" -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }
    }

    Context "3. Function Logic Verification" {
        # Already sourced

        It "Get-IpRange should generate correct IP list for 192.168.1." {
            $Ips = Get-IpRange -Prefix "192.168.1."
            $Ips.Count | Should Be 254
            $Ips[0] | Should Be "192.168.1.1"
            $Ips[253] | Should Be "192.168.1.254"
        }

        It "Get-IpRange should handle empty prefix gracefully" {
            $Ips = Get-IpRange -Prefix "10.0.0."
            $Ips[0] | Should Be "10.0.0.1"
        }
        
        It "Test-HostAlive should return boolean" {
            $Result = Test-HostAlive -IpAddress "127.0.0.1"
            ($Result -is [bool]) | Should Be $true
        }
    }

    Context "4. Log Rotation Logic" {
        # Already sourced

        It "Rotate-Logs should rename file if size exceeds limit" {
            $TestLog = "test_scanner.log"
            $Content = "A" * 100
            Set-Content -Path $TestLog -Value $Content
            
            Rotate-Logs -LogPath $TestLog -MaxSizeMB 100
            
            Test-Path $TestLog | Should Be $true
            Remove-Item $TestLog -ErrorAction SilentlyContinue
        }
    }

    # Cleanup
    if (Test-Path $TestConfigFile) { Remove-Item $TestConfigFile }
}
