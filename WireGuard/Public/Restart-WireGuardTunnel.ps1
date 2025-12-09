function Restart-WireGuardTunnel {
    <#
    .SYNOPSIS
    Restarts a WireGuard VPN tunnel.

    .DESCRIPTION
    Stops and then starts the specified WireGuard tunnel.

    .PARAMETER TunnelName
    Name of the WireGuard tunnel to restart. If not specified, uses default from config.

    .EXAMPLE
    Restart-WireGuardTunnel

    .EXAMPLE
    Restart-WireGuardTunnel -TunnelName 'work'
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

    Stop-WireGuardTunnel -TunnelName $TunnelName
    Start-Sleep -Seconds 1
    Start-WireGuardTunnel -TunnelName $TunnelName
}

Set-Alias -Name "wgrestart" -Value Restart-WireGuardTunnel
