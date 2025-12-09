function Set-WireGuardStartupMode {
    <#
    .SYNOPSIS
    Sets the startup mode for a WireGuard tunnel service.

    .DESCRIPTION
    Configures whether the WireGuard tunnel service starts automatically at boot or requires manual start.

    .PARAMETER TunnelName
    Name of the WireGuard tunnel to configure. If not specified, uses default from config.

    .PARAMETER StartupType
    The startup mode for the service: 'Auto' (start at boot) or 'Manual' (start only when requested).

    .EXAMPLE
    Set-WireGuardStartupMode -StartupType Manual

    .EXAMPLE
    Set-WireGuardStartupMode -TunnelName 'work' -StartupType Manual

    .EXAMPLE
    Set-WireGuardStartupMode -StartupType Auto
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TunnelName,

        [Parameter(Mandatory)]
        [ValidateSet('Auto', 'Manual')]
        [string]$StartupType
    )

    # Load config
    $config = Get-ModuleConfig -ModuleName 'WireGuard' `
        -SchemaPath "$PSScriptRoot/../config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"

    if (-not $TunnelName) {
        $TunnelName = $config.wireguard.defaultTunnel
    }

    $serviceName = "WireGuardTunnel`$$TunnelName"
    $startMode = if ($StartupType -eq 'Auto') { 'auto' } else { 'demand' }

    Write-Host "Configuring WireGuard tunnel '$TunnelName' startup mode..." -ForegroundColor Cyan

    # Use Start-Process with RunAs to elevate
    $result = Start-Process -FilePath "sc.exe" -ArgumentList "config", $serviceName, "start=", $startMode -Verb RunAs -Wait -PassThru

    if ($result.ExitCode -eq 0) {
        Write-Host "✓ Startup mode set to: $StartupType" -ForegroundColor Green

        if ($StartupType -eq 'Manual') {
            Write-Host "  The tunnel will NOT start automatically at boot." -ForegroundColor Yellow
            Write-Host "  Use 'wgstart' or 'Start-WireGuardTunnel' to start it manually." -ForegroundColor Gray
        }
        else {
            Write-Host "  The tunnel will start automatically at boot." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "✗ Failed to configure startup mode (Exit code: $($result.ExitCode))" -ForegroundColor Red
        Write-Host "  Make sure the service name is correct and you have administrator privileges." -ForegroundColor Gray
    }
}

Set-Alias -Name "wgstartup" -Value Set-WireGuardStartupMode
