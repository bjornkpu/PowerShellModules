function Stop-WireGuardTunnel {
    <#
    .SYNOPSIS
    Stops a WireGuard VPN tunnel.

    .DESCRIPTION
    Stops the specified WireGuard tunnel service with elevated privileges.

    .PARAMETER TunnelName
    Name of the WireGuard tunnel to stop. If not specified, uses default from config.

    .EXAMPLE
    Stop-WireGuardTunnel

    .EXAMPLE
    Stop-WireGuardTunnel -TunnelName 'work'
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

    Write-Host "Stopping WireGuard tunnel: $TunnelName" -ForegroundColor Cyan

    # Use Start-Process with RunAs to elevate
    $result = Start-Process -FilePath "sc.exe" -ArgumentList "stop", $serviceName -Verb RunAs -Wait -PassThru

    if ($result.ExitCode -eq 0) {
        Write-Host "✓ Tunnel stopped successfully" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Failed to stop tunnel (Exit code: $($result.ExitCode))" -ForegroundColor Red
    }
}

Set-Alias -Name "wgstop" -Value Stop-WireGuardTunnel
