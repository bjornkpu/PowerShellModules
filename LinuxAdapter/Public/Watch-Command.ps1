function Watch-Command {
    <#
    .SYNOPSIS
        Executes a command repeatedly at specified intervals (Linux 'watch' equivalent).

    .DESCRIPTION
        Runs a PowerShell command or script block repeatedly, displaying the output
        and updating the screen at the specified interval. Similar to the Linux 'watch' command.

    .PARAMETER Command
        The PowerShell command or script block to execute repeatedly.

    .PARAMETER Interval
        The interval in seconds between executions. Default is 2 seconds.

    .PARAMETER Differences
        Highlight differences between successive updates (not yet implemented).

    .EXAMPLE
        watch { Get-Date }
        Displays the current date/time, updating every 2 seconds.

    .EXAMPLE
        watch -Interval 5 { Get-Process | Select-Object -First 10 }
        Shows top 10 processes, updating every 5 seconds.

    .EXAMPLE
        watch -Interval 1 { Get-Service | Where-Object Status -eq 'Running' | Measure-Object | Select-Object -ExpandProperty Count }
        Counts running services every second.
    #>
    [CmdletBinding()]
    [Alias('watch')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ScriptBlock]$Command,

        [Parameter(Position = 1)]
        [Alias('n')]
        [ValidateRange(0.1, 3600)]
        [double]$Interval = 2,

        [Parameter()]
        [Alias('d', 'diff')]
        [switch]$Differences
    )

    $previousOutput = $null
    $iteration = 0

    try {
        while ($true) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            # Clear the screen
            Clear-Host

            # Display header
            Write-Host "Every $($Interval)s: " -NoNewline -ForegroundColor Cyan
            Write-Host "$Command" -ForegroundColor White
            Write-Host "$timestamp" -ForegroundColor Gray
            Write-Host ""

            # Execute the command
            try {
                $output = & $Command | Out-String

                if ($Differences -and $null -ne $previousOutput) {
                    # Compare and highlight differences
                    $currentLines = $output -split "`n"
                    $previousLines = $previousOutput -split "`n"

                    $maxLines = [Math]::Max($currentLines.Count, $previousLines.Count)
                    for ($i = 0; $i -lt $maxLines; $i++) {
                        $currentLine = if ($i -lt $currentLines.Count) { $currentLines[$i] } else { "" }
                        $previousLine = if ($i -lt $previousLines.Count) { $previousLines[$i] } else { "" }

                        if ($currentLine -ne $previousLine) {
                            Write-Host $currentLine -ForegroundColor Yellow
                        }
                        else {
                            Write-Host $currentLine
                        }
                    }
                }
                else {
                    # Just display the output
                    Write-Host $output
                }

                $previousOutput = $output
            }
            catch {
                Write-Host "Error executing command: $_" -ForegroundColor Red
            }

            # Display iteration count
            $iteration++
            Write-Host "`nIteration: $iteration | Press Ctrl+C to exit" -ForegroundColor DarkGray

            # Wait for the specified interval
            Start-Sleep -Seconds $Interval
        }
    }
    catch {
        # Handle Ctrl+C gracefully
        if ($_.Exception.Message -like "*pipeline*stopped*" -or
            $_.Exception -is [System.Management.Automation.PipelineStoppedException]) {
            Write-Host "`n`nWatch terminated." -ForegroundColor Green
        }
        else {
            throw
        }
    }
}
