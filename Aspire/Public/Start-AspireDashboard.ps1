function Start-AspireDashboard {
    <#
    .SYNOPSIS
        Starts the .NET Aspire Dashboard container

    .DESCRIPTION
        Starts the Aspire Dashboard in a container using Docker or Podman.
        If the container is already running, it retrieves and opens the login URL.

    .EXAMPLE
        Start-AspireDashboard

    .EXAMPLE
        dashboard
    #>

    [CmdletBinding()]
    [Alias('dashboard', 'dashboard-start')]
    param()

    # Load config (lazy initialization with caching)
    if (-not $script:config) {
        $script:config = Get-ModuleConfig -ModuleName 'Aspire'
    }

    $runtime = $script:config.aspire.containerRuntime
    $containerName = $script:config.aspire.containerName
    $dashboardPort = $script:config.aspire.dashboardPort
    $otlpPort = $script:config.aspire.otlpPort
    $image = $script:config.aspire.image
    $openBrowser = $script:config.aspire.openBrowser

    # Check if runtime is available
    $runtimeCmd = Get-Command $runtime -ErrorAction SilentlyContinue
    if (-not $runtimeCmd) {
        Write-Error "$runtime not found. Install it or update your config with: Reset-ModuleConfig -ModuleName Aspire"
        return
    }

    # Check if container is already running
    $existing = & $runtime ps --filter "name=$containerName" --format "{{.Names}}" 2>$null
    if ($existing -eq $containerName) {
        Write-Host "✓ Aspire Dashboard is already running" -ForegroundColor Green

        # Get login URL from logs
        $loginLine = & $runtime container logs $containerName 2>$null | Select-String "Login to the dashboard at"
        if ($loginLine) {
            $match = [regex]::Match($loginLine, "(http://localhost:\d+/login\?t=\S+)")
            if ($match.Success) {
                $url = $match.Value
                Write-Host "Dashboard URL: $url" -ForegroundColor Cyan

                if ($openBrowser) {
                    Start-Process $url
                    Write-Host "Opening dashboard in browser..." -ForegroundColor Cyan
                }
            }
        }
        return
    }

    Write-Host "🚀 Starting Aspire Dashboard..." -ForegroundColor Cyan
    Write-Host "   Container Runtime: $runtime" -ForegroundColor Gray
    Write-Host "   Dashboard Port: $dashboardPort" -ForegroundColor Gray
    Write-Host "   OTLP Port: $otlpPort" -ForegroundColor Gray

    # Start the container
    & $runtime run --rm -it -d `
        -p "${dashboardPort}:18888" `
        -p "${otlpPort}:18889" `
        --name $containerName `
        $image | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start Aspire Dashboard container"
        return
    }

    # Wait for container to initialize
    Start-Sleep -Seconds 2

    # Get login URL from logs
    $loginLine = & $runtime container logs $containerName 2>$null | Select-String "Login to the dashboard at"
    if ($loginLine) {
        $match = [regex]::Match($loginLine, "(http://localhost:\d+/login\?t=\S+)")
        if ($match.Success) {
            $url = $match.Value
            Write-Host "✓ Dashboard started successfully!" -ForegroundColor Green
            Write-Host "Dashboard URL: $url" -ForegroundColor Cyan

            if ($openBrowser) {
                Start-Process $url
                Write-Host "Opening dashboard in browser..." -ForegroundColor Cyan
            }
        }
        else {
            Write-Warning "Login URL not found in logs"
        }
    }
    else {
        Write-Warning "Login line not found in container logs. The container may still be starting."
        Write-Host "Try running: $runtime container logs $containerName" -ForegroundColor Gray
    }
}
