function Start-DatabricksKeepAlive {
    <#
    .SYNOPSIS
    Keeps a Databricks cluster alive by periodically running a lightweight notebook.

    .DESCRIPTION
    Prevents cluster auto-termination by submitting a simple SQL query (%sql SELECT 1)
    every 30 minutes (configurable). Runs in the foreground - press Ctrl+C to stop.
    The cluster will auto-terminate normally after you stop the keep-alive loop.

    .EXAMPLE
    Start-DatabricksKeepAlive

    .EXAMPLE
    d keep-alive
    #>
    [CmdletBinding()]
    param()

    # Load config
    $config = Get-ModuleConfig -ModuleName 'Databricks' `
        -SchemaPath "$PSScriptRoot/../Schemas/config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"

    $dbConfig = $config.databricks
    $dbProfile = if ($dbConfig.profile) { $dbConfig.profile } else { "DEFAULT" }

    # Get keep-alive interval (default 30 minutes)
    $intervalMinutes = if ($dbConfig.keepAliveIntervalMinutes) {
        $dbConfig.keepAliveIntervalMinutes
    }
    else {
        30
    }
    $intervalSeconds = $intervalMinutes * 60

    # Create keep-alive notebook path
    $notebookPath = "/Workspace/Users/$($dbConfig.accountId)/.databricks-keep-alive"
    $notebookContent = "-- Databricks notebook source`n-- MAGIC %sql SELECT 1 AS keep_alive"

    Write-Host "Databricks Cluster Keep-Alive" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "Cluster ID: $($dbConfig.clusterId)" -ForegroundColor White
    Write-Host "Interval: $intervalMinutes minutes" -ForegroundColor White
    Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
    Write-Host ""

    try {
        # Create temporary notebook (overwrite if exists)
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Creating keep-alive notebook at $notebookPath..." -ForegroundColor Gray

        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value $notebookContent -NoNewline

        $importResult = databricks workspace import -p $dbProfile --file $tempFile --language SQL --format SOURCE --overwrite $notebookPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create keep-alive notebook: $importResult"
        }
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Keep-alive notebook created successfully" -ForegroundColor Green
        Write-Host ""

        # Keep-alive loop
        $runCount = 0
        while ($true) {
            $runCount++
            Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Run #$runCount - Submitting notebook job..." -ForegroundColor Cyan

            # Build JSON for one-time run
            $runJson = @{
                "run_name" = "databricks-keep-alive-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                "tasks"    = @(
                    @{
                        "task_key"            = "keep_alive_task"
                        "existing_cluster_id" = $dbConfig.clusterId
                        "notebook_task"       = @{
                            "notebook_path" = $notebookPath
                            "source"        = "WORKSPACE"
                        }
                    }
                )
            } | ConvertTo-Json -Depth 5

            # Write JSON to temp file
            $jsonFile = [System.IO.Path]::GetTempFileName()
            $runJson | Out-File -FilePath $jsonFile -Encoding utf8 -NoNewline

            # Submit the run
            $submitResult = databricks jobs submit -p $dbProfile --json "@$jsonFile" 2>&1 | Out-String
            Remove-Item -Path $jsonFile -Force -ErrorAction SilentlyContinue

            try {
                $submitResult = $submitResult | ConvertFrom-Json
            }
            catch {
                Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Warning: Failed to submit run - $submitResult" -ForegroundColor Yellow
                $submitResult = $null
            }

            if (-not $submitResult.run_id) {
                Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Warning: Failed to submit run" -ForegroundColor Yellow
            }
            else {
                $runId = $submitResult.run_id
                Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Job submitted (Run ID: $runId)" -ForegroundColor Gray

                # Wait for run to complete (with timeout)
                $maxWaitSeconds = 120
                $waitedSeconds = 0
                $runCompleted = $false

                while ($waitedSeconds -lt $maxWaitSeconds -and -not $runCompleted) {
                    Start-Sleep -Seconds 5
                    $waitedSeconds += 5

                    try {
                        $runStatusJson = databricks jobs get-run -p $dbProfile --run-id $runId 2>&1 | Out-String

                        # Check if response contains an error
                        if ($runStatusJson -match '^Error:') {
                            continue
                        }

                        $runStatus = $runStatusJson | ConvertFrom-Json -ErrorAction Stop
                    }
                    catch {
                        # Ignore JSON parsing errors and continue waiting
                        continue
                    }

                    if ($runStatus -and $runStatus.state.life_cycle_state -in @('TERMINATED', 'SKIPPED', 'INTERNAL_ERROR')) {
                        $runCompleted = $true
                        $resultState = $runStatus.state.result_state

                        if ($resultState -eq 'SUCCESS') {
                            Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] ✓ Keep-alive job completed successfully" -ForegroundColor Green
                        }
                        else {
                            Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] ✗ Keep-alive job failed: $resultState" -ForegroundColor Yellow
                        }
                    }
                }

                if (-not $runCompleted) {
                    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Job still running after $maxWaitSeconds seconds (continuing anyway)" -ForegroundColor Gray
                }
            }

            # Sleep until next run
            Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Sleeping for $intervalMinutes minutes until next run..." -ForegroundColor Gray
            Write-Host ""
            Start-Sleep -Seconds $intervalSeconds
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        # Ctrl+C pressed
        Write-Host ""
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Keep-alive stopped by user" -ForegroundColor Yellow
    }
    catch {
        Write-Host ""
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Error: $_" -ForegroundColor Red
        throw
    }
    finally {
        # Cleanup: Remove the keep-alive notebook
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Cleaning up keep-alive notebook..." -ForegroundColor Gray

        $deleteResult = databricks workspace delete -p $dbProfile $notebookPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Keep-alive notebook removed" -ForegroundColor Green
        }
        else {
            Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Warning: Could not remove keep-alive notebook" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Cluster will auto-terminate after $($dbConfig.autotermination_minutes ?? 40) minutes of inactivity" -ForegroundColor Cyan
    }
}
