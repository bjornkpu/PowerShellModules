function Command-Start {
    <#
    .SYNOPSIS
    Start a Databricks cluster.

    .DESCRIPTION
    Starts the configured Databricks cluster. Uses default cluster unless an
    environment is specified.

    .PARAMETER Environment
    Optional environment name (e.g., 'dev', 'prod'). Uses default configuration if not specified.

    .EXAMPLE
    d start
    Starts the default cluster

    .EXAMPLE
    d start -Environment prod
    Starts the production cluster

    .NOTES
    The cluster must be in TERMINATED state to be started.
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

    Write-Host "Starting cluster..." -ForegroundColor Cyan
    databricks clusters start $envConfig.clusterId -p $envConfig.profile
}
