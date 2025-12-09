function Start-WireGuardTunnel {
    <#
    .SYNOPSIS
    Starts a WireGuard VPN tunnel.

    .DESCRIPTION
    Starts the specified WireGuard tunnel service with elevated privileges.

    .PARAMETER TunnelName
    Name of the WireGuard tunnel to start. If not specified, uses default from config.

    .EXAMPLE
    Start-WireGuardTunnel

    .EXAMPLE
    Start-WireGuardTunnel -TunnelName 'work'
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TunnelName
    )

    # Load config
    $config = Get-ModuleConfig -ModuleName 'WireGuard' `
        -SchemaPath "$PSScriptRoot/../config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"

    if (-not $TunnelName) {
        $TunnelName = $config.wireguard.defaultTunnel
    }

    $serviceName = "WireGuardTunnel`$$TunnelName"

    Write-Host "Starting WireGuard tunnel: $TunnelName" -ForegroundColor Cyan

    # Use Start-Process with RunAs to elevate
    $result = Start-Process -FilePath "sc.exe" -ArgumentList "start", $serviceName -Verb RunAs -Wait -PassThru

    if ($result.ExitCode -eq 0) {
        Write-Host "✓ Tunnel started successfully" -ForegroundColor Green
        Start-Sleep -Seconds 2
        Get-WireGuardStatus -TunnelName $TunnelName
    }
    elseif ($result.ExitCode -eq 1056) {
        Write-Host "✓ Tunnel is already running" -ForegroundColor Yellow
        Get-WireGuardStatus -TunnelName $TunnelName
    }
    else {
        Write-Host "✗ Failed to start tunnel (Exit code: $($result.ExitCode))" -ForegroundColor Red
    }
}

Set-Alias -Name "wgstart" -Value Start-WireGuardTunnel
