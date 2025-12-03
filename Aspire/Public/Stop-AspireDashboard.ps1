function Stop-AspireDashboard {
    <#
    .SYNOPSIS
        Stops the .NET Aspire Dashboard container

    .DESCRIPTION
        Stops the running Aspire Dashboard container.

    .EXAMPLE
        Stop-AspireDashboard

    .EXAMPLE
        dashboard-stop
    #>

    [CmdletBinding()]
    [Alias('dashboard-stop')]
    param()

    # Load config (lazy initialization with caching)
    if (-not $script:config) {
        $script:config = Get-ModuleConfig -ModuleName 'Aspire'
    }

    $runtime = $script:config.aspire.containerRuntime
    $containerName = $script:config.aspire.containerName

    # Check if runtime is available
    $runtimeCmd = Get-Command $runtime -ErrorAction SilentlyContinue
    if (-not $runtimeCmd) {
        Write-Error "$runtime not found. Install it or update your config with: Reset-ModuleConfig -ModuleName Aspire"
        return
    }

    # Check if container is running
    $existing = & $runtime ps --filter "name=$containerName" --format "{{.Names}}" 2>$null
    if ($existing -ne $containerName) {
        Write-Warning "Aspire Dashboard is not running"
        return
    }

    Write-Host "🛑 Stopping Aspire Dashboard..." -ForegroundColor Cyan

    & $runtime stop $containerName | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Dashboard stopped successfully" -ForegroundColor Green
    }
    else {
        Write-Error "Failed to stop Aspire Dashboard container"
    }
}
