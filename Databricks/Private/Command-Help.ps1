function Command-Help {
    <#
    .SYNOPSIS
    Display help for Databricks commands.

    .DESCRIPTION
    Shows help information for Databricks CLI commands. When called without arguments,
    displays the main help. When called with a command name, shows detailed help for that command.

    .PARAMETER CommandName
    Optional command name to get detailed help for (e.g., 'upload', 'start')

    .EXAMPLE
    d help
    Shows main help with command list

    .EXAMPLE
    d help upload
    Shows detailed help for the upload command
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$CommandName
    )

    if ($CommandName) {
        # Show help for specific command by displaying its documentation
        switch ($CommandName.ToLower()) {
            'login' {
                Write-Host "`nCOMMAND: login" -ForegroundColor Cyan
                Write-Host "Authenticate with Databricks workspace.`n" -ForegroundColor White
                Write-Host "USAGE:" -ForegroundColor Yellow
                Write-Host "  d login [-Environment <name>]`n"
                Write-Host "PARAMETERS:" -ForegroundColor Yellow
                Write-Host "  -Environment    Optional environment name (e.g., 'dev', 'prod')`n"
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  d login"
                Write-Host "  d login -Environment prod`n"
            }
            'start' {
                Write-Host "`nCOMMAND: start" -ForegroundColor Cyan
                Write-Host "Start a Databricks cluster.`n" -ForegroundColor White
                Write-Host "USAGE:" -ForegroundColor Yellow
                Write-Host "  d start [-Environment <name>]`n"
                Write-Host "PARAMETERS:" -ForegroundColor Yellow
                Write-Host "  -Environment    Optional environment name (e.g., 'dev', 'prod')`n"
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  d start"
                Write-Host "  d start -Environment prod`n"
            }
            'stop' {
                Write-Host "`nCOMMAND: stop" -ForegroundColor Cyan
                Write-Host "Stop a Databricks cluster.`n" -ForegroundColor White
                Write-Host "USAGE:" -ForegroundColor Yellow
                Write-Host "  d stop [-Environment <name>]`n"
                Write-Host "PARAMETERS:" -ForegroundColor Yellow
                Write-Host "  -Environment    Optional environment name (e.g., 'dev', 'prod')`n"
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  d stop"
                Write-Host "  d stop -Environment prod`n"
            }
            { $_ -in @('list', 'ls') } {
                Write-Host "`nCOMMAND: list (alias: ls)" -ForegroundColor Cyan
                Write-Host "List personal Databricks clusters.`n" -ForegroundColor White
                Write-Host "USAGE:" -ForegroundColor Yellow
                Write-Host "  d list [-State <state>] [-Environment <name>]"
                Write-Host "  d ls [-State <state>] [-Environment <name>]`n"
                Write-Host "PARAMETERS:" -ForegroundColor Yellow
                Write-Host "  -State          Filter by state: 'Running', 'Terminated', or 'All' (default: All)"
                Write-Host "  -Environment    Optional environment name (e.g., 'dev', 'prod')`n"
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  d list"
                Write-Host "  d ls -State Running"
                Write-Host "  d list -State Terminated -Environment prod`n"
                Write-Host "NOTES:" -ForegroundColor Yellow
                Write-Host "  Automatically excludes job clusters. Only shows personal/interactive clusters.`n"
            }
            'upload' {
                Write-Host "`nCOMMAND: upload" -ForegroundColor Cyan
                Write-Host "Upload a Python package to Databricks workspace.`n" -ForegroundColor White
                Write-Host "USAGE:" -ForegroundColor Yellow
                Write-Host "  d upload [<version>] [-Environment <name>]`n"
                Write-Host "PARAMETERS:" -ForegroundColor Yellow
                Write-Host "  -Version        Package version (e.g., '1.2.3'). Auto-detected from pyproject.toml if omitted."
                Write-Host "  -Environment    Optional environment name (e.g., 'dev', 'prod')`n"
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  d upload"
                Write-Host "  d upload -Version 1.2.3"
                Write-Host "  d upload -Version 1.2.3 -Environment prod`n"
                Write-Host "NOTES:" -ForegroundColor Yellow
                Write-Host "  The .whl file must exist in the dist/ directory before uploading.`n"
            }
            'install' {
                Write-Host "`nCOMMAND: install" -ForegroundColor Cyan
                Write-Host "Install a Python package on Databricks cluster.`n" -ForegroundColor White
                Write-Host "USAGE:" -ForegroundColor Yellow
                Write-Host "  d install [<version>] [-Environment <name>]`n"
                Write-Host "PARAMETERS:" -ForegroundColor Yellow
                Write-Host "  -Version        Package version (e.g., '1.2.3'). Auto-detected from pyproject.toml if omitted."
                Write-Host "  -Environment    Optional environment name (e.g., 'dev', 'prod')`n"
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  d install"
                Write-Host "  d install -Version 1.2.3"
                Write-Host "  d install -Version 1.2.3 -Environment prod`n"
                Write-Host "NOTES:" -ForegroundColor Yellow
                Write-Host "  The package must have been uploaded to workspace before installation.`n"
            }
            'upstall' {
                Write-Host "`nCOMMAND: upstall" -ForegroundColor Cyan
                Write-Host "Upload and install a Python package in one step.`n" -ForegroundColor White
                Write-Host "USAGE:" -ForegroundColor Yellow
                Write-Host "  d upstall [<version>] [-Environment <name>]`n"
                Write-Host "PARAMETERS:" -ForegroundColor Yellow
                Write-Host "  -Version        Package version (e.g., '1.2.3'). Auto-detected from pyproject.toml if omitted."
                Write-Host "  -Environment    Optional environment name (e.g., 'dev', 'prod')`n"
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  d upstall"
                Write-Host "  d upstall -Version 1.2.3"
                Write-Host "  d upstall -Version 1.2.3 -Environment prod`n"
                Write-Host "NOTES:" -ForegroundColor Yellow
                Write-Host "  This is the most common workflow for deploying package updates.`n"
            }
            'keep-alive' {
                Write-Host "`nCOMMAND: keep-alive" -ForegroundColor Cyan
                Write-Host "Keep a Databricks cluster alive with periodic heartbeat.`n" -ForegroundColor White
                Write-Host "USAGE:" -ForegroundColor Yellow
                Write-Host "  d keep-alive [-Environment <name>]`n"
                Write-Host "PARAMETERS:" -ForegroundColor Yellow
                Write-Host "  -Environment    Optional environment name (e.g., 'dev', 'prod')`n"
                Write-Host "EXAMPLES:" -ForegroundColor Yellow
                Write-Host "  d keep-alive"
                Write-Host "  d keep-alive -Environment prod`n"
                Write-Host "NOTES:" -ForegroundColor Yellow
                Write-Host "  Runs in foreground - press Ctrl+C to stop."
                Write-Host "  Keep-alive interval is configured in config.json (keepAliveIntervalMinutes).`n"
            }
            default {
                Write-Host "No help available for command: $CommandName" -ForegroundColor Yellow
                Write-Host "Available commands: login, start, stop, list, ls, upload, install, upstall, keep-alive" -ForegroundColor Cyan
            }
        }
    }
    else {
        # Show main help
        Get-Help Invoke-DatabricksCommand
    }
}
