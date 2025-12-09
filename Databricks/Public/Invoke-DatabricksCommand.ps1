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

    .EXAMPLE
    Invoke-DatabricksCommand -Command login

    .EXAMPLE
    d start

    .EXAMPLE
    d upstall 1.9.18
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('login', 'start', 'stop', 'list', 'ls', 'upload', 'install', 'upstall', 'keep-alive')]
        [string]$Command,

        [Parameter(Position = 1)]
        [string]$PackageVersion
    )

    # Load config
    $config = Get-ModuleConfig -ModuleName 'Databricks' `
        -SchemaPath "$PSScriptRoot/../config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"

    $dbConfig = $config.databricks
    $dbProfile = if ($dbConfig.profile) { $dbConfig.profile } else { "DEFAULT" }

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
            databricks auth login --host $dbConfig.host --account-id $dbConfig.accountId -p $dbProfile
        }
        "start" {
            Write-Host "Starting cluster..." -ForegroundColor Cyan
            databricks clusters start $dbConfig.clusterId -p $dbProfile
        }
        "stop" {
            Write-Host "Stopping cluster..." -ForegroundColor Cyan
            databricks clusters stop $dbConfig.clusterId -p $dbProfile
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
                "cluster_id" = $dbConfig.clusterId
                "libraries"  = @(
                    @{
                        "whl" = "/Workspace/Users/$($dbConfig.accountId)/$fileName"
                    }
                )
            } | ConvertTo-Json -Depth 3
            databricks libraries install -p $dbProfile --json $json
        }
        "upstall" {
            Invoke-DatabricksCommand -Command upload -PackageVersion $PackageVersion
            Invoke-DatabricksCommand -Command install -PackageVersion $PackageVersion
        }
        "keep-alive" {
            Start-DatabricksKeepAlive
        }
    }
}

Set-Alias -Name "d" -Value Invoke-DatabricksCommand
