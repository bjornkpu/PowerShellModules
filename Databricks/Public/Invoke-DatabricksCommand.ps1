function Invoke-DatabricksCommand {
    <#
    .SYNOPSIS
    Wrapper for common Databricks CLI commands.

    .DESCRIPTION
    Provides convenient shortcuts for Databricks operations like cluster management,
    package upload, and installation.

    .PARAMETER Command
    The Databricks command to execute: login, start, stop, list, upload, install, upstall, keep-alive

    .PARAMETER PackageVersion
    Version of the package to upload/install. Defaults to reading from pyproject.toml

    .PARAMETER Environment
    Environment to use (e.g., dev, prod). Uses environment-specific configuration from config.json

    .EXAMPLE
    Invoke-DatabricksCommand -Command login

    .EXAMPLE
    d start

    .EXAMPLE
    d upstall 1.9.18

    .EXAMPLE
    d start -Environment prod
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('login', 'start', 'stop', 'list', 'ls', 'upload', 'install', 'upstall', 'keep-alive')]
        [string]$Command,

        [Parameter(Position = 1)]
        [string]$PackageVersion,

        [Parameter()]
        [string]$Environment
    )

    # Load config
    $config = Get-ModuleConfig -ModuleName 'Databricks' `
        -SchemaPath "$PSScriptRoot/../config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"

    $dbConfig = $config.databricks

    # Apply environment-specific configuration if specified
    if ($Environment) {
        if (-not $dbConfig.environments) {
            throw "No environments configured in config.json. Please add an 'environments' section."
        }
        if (-not $dbConfig.environments.$Environment) {
            $availableEnvs = ($dbConfig.environments.PSObject.Properties.Name -join ', ')
            throw "Environment '$Environment' not found in config. Available environments: $availableEnvs"
        }

        $envConfig = $dbConfig.environments.$Environment
        Write-Host "Using environment: $Environment" -ForegroundColor Magenta

        # Override with environment-specific values
        $dbProfile = $envConfig.profile
        $dbHost = $envConfig.host
        $dbClusterId = $envConfig.clusterId
    }
    else {
        # Use default configuration
        $dbProfile = if ($dbConfig.profile) { $dbConfig.profile } else { "DEFAULT" }
        $dbHost = $dbConfig.host
        $dbClusterId = $dbConfig.clusterId
    }

    # If version not specified, try to read from pyproject.toml
    if (-not $PackageVersion -and ($Command -in @('upload', 'install', 'upstall'))) {
        $pyprojectPath = Join-Path $dbConfig.workspacePath "$($dbConfig.defaultPackage)\pyproject.toml"
        if (Test-Path $pyprojectPath) {
            $content = Get-Content $pyprojectPath -Raw
            if ($content -match 'version\s*=\s*"(\d+\.\d+\.\d+)"') {
                $PackageVersion = $matches[1]
                Write-Host "Using version from pyproject.toml: $PackageVersion" -ForegroundColor Cyan
            }
        }
        if (-not $PackageVersion) {
            throw "Package version not specified and could not be read from pyproject.toml"
        }
    }

    switch ($Command) {
        "login" {
            Write-Host "Logging into Databricks..." -ForegroundColor Cyan
            databricks auth login --host $dbHost --account-id $dbConfig.accountId -p $dbProfile
        }
        "start" {
            Write-Host "Starting cluster..." -ForegroundColor Cyan
            databricks clusters start $dbClusterId -p $dbProfile
        }
        "stop" {
            Write-Host "Stopping cluster..." -ForegroundColor Cyan
            databricks clusters stop $dbClusterId -p $dbProfile
        }
        { $_ -in @("list", "ls") } {
            Write-Host "Listing clusters..." -ForegroundColor Cyan
            databricks clusters list -p $dbProfile
        }
        "upload" {
            Write-Host "Uploading package version $PackageVersion..." -ForegroundColor Cyan
            $fileName = "$($dbConfig.defaultPackage)-$PackageVersion-py3-none-any.whl"
            $localFilePath = Join-Path $dbConfig.workspacePath "$($dbConfig.defaultPackage)\dist\$fileName"
            $destinationPath = "/Workspace/Users/$($dbConfig.accountId)/$fileName"

            if (-not (Test-Path $localFilePath)) {
                throw "Package file not found: $localFilePath"
            }

            databricks workspace import --overwrite -p $dbProfile --file $localFilePath --format AUTO $destinationPath
        }
        "install" {
            Write-Host "Installing version $PackageVersion on cluster..." -ForegroundColor Cyan
            $fileName = "$($dbConfig.defaultPackage)-$PackageVersion-py3-none-any.whl"
            $json = @{
                "cluster_id" = $dbClusterId
                "libraries"  = @(
                    @{
                        "whl" = "/Workspace/Users/$($dbConfig.accountId)/$fileName"
                    }
                )
            } | ConvertTo-Json -Depth 3
            databricks libraries install -p $dbProfile --json $json
        }
        "upstall" {
            $params = @{
                PackageVersion = $PackageVersion
            }
            if ($Environment) {
                $params.Environment = $Environment
            }
            Invoke-DatabricksCommand -Command upload @params
            Invoke-DatabricksCommand -Command install @params
        }
        "keep-alive" {
            Start-DatabricksKeepAlive
        }
    }
}

Set-Alias -Name "d" -Value Invoke-DatabricksCommand
