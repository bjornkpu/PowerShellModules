function Command-KeepAlive {
    <#
    .SYNOPSIS
    Keep a Databricks cluster alive with periodic heartbeat.

    .DESCRIPTION
    Prevents cluster auto-termination by periodically submitting a lightweight notebook job
    every 30 minutes (configurable in config.json). Runs in the foreground - press Ctrl+C to stop.
    The cluster will auto-terminate normally after you stop the keep-alive loop.

    .PARAMETER Environment
    Optional environment name (e.g., 'dev', 'prod'). Uses default configuration if not specified.

    .EXAMPLE
    d keep-alive
    Starts keep-alive loop for default cluster

    .EXAMPLE
    d keep-alive -Environment prod
    Starts keep-alive loop for production cluster

    .NOTES
    This delegates to Start-DatabricksKeepAlive function.
    The keep-alive interval is configured in config.json (keepAliveIntervalMinutes).
    Press Ctrl+C to stop the keep-alive loop.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Environment
    )

    # Delegate to the full implementation
    $params = @{}
    if ($Environment) { $params.Environment = $Environment }
    
    Start-DatabricksKeepAlive @params
}
