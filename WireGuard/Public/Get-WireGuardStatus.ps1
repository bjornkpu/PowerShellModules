function Get-WireGuardStatus {
    <#
    .SYNOPSIS
    Gets the status of WireGuard tunnels.
    
    .DESCRIPTION
    Displays the current status of WireGuard tunnels using the wg.exe tool.
    
    .PARAMETER TunnelName
    Name of the WireGuard tunnel to check. If not specified, shows all tunnels.
    
    .EXAMPLE
    Get-WireGuardStatus
    
    .EXAMPLE
    Get-WireGuardStatus -TunnelName 'home'
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TunnelName
    )

    # Load config
    $config = Get-ModuleConfig -ModuleName 'WireGuard' `
        -SchemaPath "$PSScriptRoot/../Schemas/config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"
    
    $wgPath = $config.wireguard.wireguardPath

    Write-Host "Checking WireGuard status..." -ForegroundColor Cyan

    # Create a temporary PowerShell script to run elevated
    $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
    $tempOutput = [System.IO.Path]::GetTempFileName()

    $args = if ($TunnelName) { "show $TunnelName" } else { "show" }

    $scriptContent = @"
& '$wgPath' $args | Out-File -FilePath '$tempOutput' -Encoding utf8
"@

    Set-Content -Path $tempScript -Value $scriptContent

    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy", "Bypass", "-File", $tempScript -Verb RunAs -Wait -WindowStyle Hidden

    if (Test-Path $tempOutput) {
        $output = Get-Content $tempOutput -Raw
        Remove-Item $tempOutput -Force

        if ($output -and $output.Trim()) {
            Write-Host $output
        }
        else {
            Write-Host "No active tunnels" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Failed to get status" -ForegroundColor Red
    }

    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
}

Set-Alias -Name "wgstatus" -Value Get-WireGuardStatus
