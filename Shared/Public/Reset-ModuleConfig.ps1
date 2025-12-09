function Reset-ModuleConfig {
    <#
    .SYNOPSIS
    Resets module configuration by running interactive setup again.

    .DESCRIPTION
    Deletes existing configuration and triggers Initialize-ModuleConfig to recreate it.

    .PARAMETER ModuleName
    Name of the module to reset configuration for.

    .PARAMETER SchemaPath
    Path to the JSON schema file.

    .PARAMETER ExampleConfigPath
    Path to the example config file.

    .EXAMPLE
    Reset-ModuleConfig -ModuleName 'Databricks' -SchemaPath "./config.schema.json" -ExampleConfigPath "./config.example.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$SchemaPath,

        [Parameter(Mandatory)]
        [string]$ExampleConfigPath
    )

    $configDir = Join-Path $env:USERPROFILE ".config\$ModuleName"
    $configPath = Join-Path $configDir "config.json"

    if (Test-Path $configPath) {
        $confirmation = Read-Host "Are you sure you want to reset the configuration for '$ModuleName'? (y/N)"
        if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
            Remove-Item -Path $configPath -Force
            Write-Host "Configuration deleted." -ForegroundColor Yellow
        }
        else {
            Write-Host "Reset cancelled." -ForegroundColor Yellow
            return
        }
    }

    Initialize-ModuleConfig -ModuleName $ModuleName -SchemaPath $SchemaPath -ExampleConfigPath $ExampleConfigPath
}
