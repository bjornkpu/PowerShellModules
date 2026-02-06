function Invoke-TimeTrack {
    <#
    .SYNOPSIS
    Time tracking automation with pluggable backends and multi-system reporting.

    .DESCRIPTION
    Manages time entries via Toggl Track API, automates lunch break insertion,
    and generates weekly reports for multiple timesheet systems (TimeReg, xledger, Enova).

    .PARAMETER Command
    Command to execute: set-lunch, report, remaining

    .PARAMETER System
    Reporting system for 'report' command: timereg, xledger, enova, all

    .PARAMETER Week
    Week reference: ISO week number (1-53) or date (YYYY-MM-DD). Defaults to current week.

    .PARAMETER Month
    Month number (1-12) for 'remaining' command. Defaults to current month.

    .PARAMETER DryRun
    Preview changes without modifying Toggl entries (set-lunch only)

    .EXAMPLE
    Invoke-TimeTrack set-lunch
    Add lunch breaks to current week

    .EXAMPLE
    tt set-lunch --week 4 --dry-run
    Preview lunch break insertion for week 4

    .EXAMPLE
    tt report timereg --week 2026-01-27
    Generate TimeReg report for the week containing Jan 27

    .EXAMPLE
    tt report all
    Generate reports for all three systems (current week)

    .EXAMPLE
    tt remaining
    Show hours remaining to work this month
    #>
    [CmdletBinding()]
    [Alias('tt')]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('set-lunch', 'report', 'remaining')]
        [string]$Command,

        [Parameter(Position = 1)]
        [string]$System,

        [Parameter()]
        [string]$Week,

        [Parameter()]
        [int]$Month,

        [Parameter()]
        [switch]$DryRun
    )

    if (-not $Command) {
        Write-Host "TimeTrack - Time tracking automation" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Yellow
        Write-Host "  set-lunch   Add lunch breaks to current week"
        Write-Host "  report      Generate report for a timesheet system"
        Write-Host "  remaining   Show hours remaining to work this month"
        Write-Host ""
        Write-Host "Usage examples:" -ForegroundColor Yellow
        Write-Host "  tt set-lunch                        Add lunch breaks to current week"
        Write-Host "  tt set-lunch --week 4 --dry-run     Preview lunch break insertion for week 4"
        Write-Host "  tt report timereg --week 2026-01-27  Generate TimeReg report for week containing Jan 27"
        Write-Host "  tt report all                       Generate reports for all systems (current week)"
        Write-Host "  tt remaining                        Show hours remaining to work this month"
        return
    }

    # Lazy-load config
    if (-not $script:config) {
        $script:config = Get-ModuleConfig -ModuleName 'TimeTrack'
    }

    $pythonDir = Join-Path $PSScriptRoot "../python"

    if (-not (Test-Path $pythonDir)) {
        throw "Python package not found at $pythonDir. Run 'cd $pythonDir && uv init' to initialize."
    }

    Push-Location $pythonDir
    try {
        # Build command arguments
        $args = @($Command)

        switch ($Command) {
            'set-lunch' {
                if ($Week) { $args += @('--week', $Week) }
                if ($DryRun) { $args += '--dry-run' }
            }
            'report' {
                if (-not $System) {
                    throw "Parameter 'System' is required for 'report' command. Valid values: timereg, xledger, enova, all"
                }
                $args += $System
                if ($Week) { $args += @('--week', $Week) }
            }
            'remaining' {
                if ($Month) { $args += @('--month', $Month) }
            }
        }

        # Execute Python CLI
        uv run timetrack @args

        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
