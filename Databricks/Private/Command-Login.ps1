function Command-Login {
    <#
    .SYNOPSIS
    Authenticate with Databricks workspace.

    .DESCRIPTION
    Logs into Databricks using the configured host and account ID.
    Supports environment-specific authentication via the -Environment parameter.

    .PARAMETER Environment
    Optional environment name (e.g., 'dev', 'prod'). Uses default configuration if not specified.

    .EXAMPLE
    d login
    Logs into default Databricks workspace

    .EXAMPLE
    d login -Environment prod
    Logs into production workspace

    .NOTES
    Credentials are stored by the Databricks CLI after successful authentication.
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

    Write-Host "Logging into Databricks..." -ForegroundColor Cyan
    databricks auth login --host $envConfig.host --account-id $dbConfig.accountId -p $envConfig.profile
}
