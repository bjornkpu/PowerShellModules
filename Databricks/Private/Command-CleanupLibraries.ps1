function Command-CleanupLibraries {
    <#
    .SYNOPSIS
    Clean up stale mimir bundle libraries from a cluster.

    .DESCRIPTION
    Uninstalls all mimir bundle libraries (/.bundle/mimir/ path) from the configured cluster.
    This is useful when libraries have accumulated over time and you want to clean them up
    without restarting the cluster, or to test the cleanup independently.

    .PARAMETER Environment
    Optional environment name (e.g., 'dev', 'prod'). Uses default configuration if not specified.

    .EXAMPLE
    d cleanup-libraries
    Cleans up stale libraries from the default cluster

    .EXAMPLE
    d cleanup-libraries -Environment prod
    Cleans up stale libraries from the production cluster

    .NOTES
    This is called automatically by 'd start', but can also be run independently.
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

    Remove-StaleClusterLibraries -ClusterId $envConfig.clusterId -DatabricksProfile $envConfig.profile
}
