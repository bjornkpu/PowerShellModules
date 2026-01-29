function Get-EnvironmentConfig {
    <#
    .SYNOPSIS
    Resolves environment-specific Databricks configuration.

    .DESCRIPTION
    Returns the appropriate Databricks configuration based on the specified environment.
    If no environment is specified, returns default configuration from config.json.

    .PARAMETER Config
    The main Databricks configuration object from config.json

    .PARAMETER Environment
    The environment name (e.g., 'dev', 'prod')

    .OUTPUTS
    PSCustomObject with properties: profile, host, clusterId

    .EXAMPLE
    $envConfig = Get-EnvironmentConfig -Config $config.databricks -Environment 'prod'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter()]
        [string]$Environment
    )

    if ($Environment) {
        if (-not $Config.environments) {
            throw "No environments configured in config.json. Please add an 'environments' section."
        }
        if (-not $Config.environments.$Environment) {
            $availableEnvs = ($Config.environments.PSObject.Properties.Name -join ', ')
            throw "Environment '$Environment' not found in config. Available environments: $availableEnvs"
        }

        $envConfig = $Config.environments.$Environment
        Write-Verbose "Using environment: $Environment"

        return [PSCustomObject]@{
            profile   = $envConfig.profile
            host      = $envConfig.host
            clusterId = $envConfig.clusterId
        }
    }
    else {
        # Use default configuration
        return [PSCustomObject]@{
            profile   = if ($Config.profile) { $Config.profile } else { "DEFAULT" }
            host      = $Config.host
            clusterId = $Config.clusterId
        }
    }
}
