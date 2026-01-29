function Command-Stop {
    <#
    .SYNOPSIS
    Stop a Databricks cluster.

    .DESCRIPTION
    Stops the configured Databricks cluster. Uses default cluster unless an
    environment is specified.

    .PARAMETER Environment
    Optional environment name (e.g., 'dev', 'prod'). Uses default configuration if not specified.

    .EXAMPLE
    d stop
    Stops the default cluster

    .EXAMPLE
    d stop -Environment prod
    Stops the production cluster

    .NOTES
    The cluster must be in RUNNING state to be stopped.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Environment
    )

    $config = Get-ModuleConfig -ModuleName 'Databricks' `
        -SchemaPath "$PSScriptRoot/../config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"

    $dbConfig = $config.databricks
    $envConfig = Get-EnvironmentConfig -Config $dbConfig -Environment $Environment

    Write-Host "Stopping cluster..." -ForegroundColor Cyan
    databricks clusters stop $envConfig.clusterId -p $envConfig.profile
}
