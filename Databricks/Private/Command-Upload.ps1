function Command-Upload {
    <#
    .SYNOPSIS
    Upload a Python package to Databricks workspace.

    .DESCRIPTION
    Uploads a built Python wheel package to the Databricks workspace.
    If no version is specified, reads the version from pyproject.toml.

    .PARAMETER Version
    Package version to upload (e.g., '1.2.3'). If not specified, reads from pyproject.toml.

    .PARAMETER Environment
    Optional environment name (e.g., 'dev', 'prod'). Uses default configuration if not specified.

    .EXAMPLE
    d upload
    Uploads the package using version from pyproject.toml

    .EXAMPLE
    d upload -Version 1.2.3
    Uploads version 1.2.3 of the package

    .EXAMPLE
    d upload -Version 1.2.3 -Environment prod
    Uploads version 1.2.3 to production workspace

    .NOTES
    The .whl file must exist in the dist/ directory before uploading.
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

    Write-Host "Uploading package version $Version..." -ForegroundColor Cyan
    $fileName = "$($dbConfig.defaultPackage)-$Version-py3-none-any.whl"
    $localFilePath = Join-Path $dbConfig.workspacePath "$($dbConfig.defaultPackage)\dist\$fileName"
    $destinationPath = "/Workspace/Users/$($dbConfig.accountId)/$fileName"

    if (-not (Test-Path $localFilePath)) {
        throw "Package file not found: $localFilePath"
    }

    databricks workspace import --overwrite -p $envConfig.profile --file $localFilePath --format AUTO $destinationPath
}
