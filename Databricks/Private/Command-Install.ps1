function Command-Install {
    <#
    .SYNOPSIS
    Install a Python package on Databricks cluster.

    .DESCRIPTION
    Installs a previously uploaded Python wheel package onto the configured cluster.
    If no version is specified, reads the version from pyproject.toml.

    .PARAMETER Version
    Package version to install (e.g., '1.2.3'). If not specified, reads from pyproject.toml.

    .PARAMETER Environment
    Optional environment name (e.g., 'dev', 'prod'). Uses default configuration if not specified.

    .EXAMPLE
    d install
    Installs the package using version from pyproject.toml

    .EXAMPLE
    d install -Version 1.2.3
    Installs version 1.2.3 of the package

    .EXAMPLE
    d install -Version 1.2.3 -Environment prod
    Installs version 1.2.3 on production cluster

    .NOTES
    The package must have been uploaded to workspace before installation.
    Cluster may need to be restarted for library to take effect.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Version,

        [Parameter()]
        [string]$Environment
    )

    $config = Get-ModuleConfig -ModuleName 'Databricks' `
        -SchemaPath "$PSScriptRoot/../config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"

    $dbConfig = $config.databricks
    $envConfig = Get-EnvironmentConfig -Config $dbConfig -Environment $Environment

    # Get version from pyproject.toml if not specified
    if (-not $Version) {
        $Version = Get-PackageVersionFromPyproject -WorkspacePath $dbConfig.workspacePath -PackageName $dbConfig.defaultPackage
        Write-Host "Using version from pyproject.toml: $Version" -ForegroundColor Cyan
    }

    Write-Host "Installing version $Version on cluster..." -ForegroundColor Cyan
    $fileName = "$($dbConfig.defaultPackage)-$Version-py3-none-any.whl"
    $json = @{
        "cluster_id" = $envConfig.clusterId
        "libraries"  = @(
            @{
                "whl" = "/Workspace/Users/$($dbConfig.accountId)/$fileName"
            }
        )
    } | ConvertTo-Json -Depth 3
    databricks libraries install -p $envConfig.profile --json $json
}
