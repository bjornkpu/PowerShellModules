function Get-ModuleConfig {
    <#
    .SYNOPSIS
    Loads and validates module configuration from user's config directory.

    .DESCRIPTION
    Retrieves configuration for a PowerShell module from ~/.config/{ModuleName}/config.json.
    Validates against the module's JSON schema and caches the result in module scope.
    If config doesn't exist, triggers interactive initialization.

    Auto-discovers schema and example config from module root directory if not specified.

    .PARAMETER ModuleName
    Name of the module to load configuration for.

    .PARAMETER SchemaPath
    Path to the JSON schema file for validation. Defaults to {ModuleRoot}/config.schema.json

    .PARAMETER ExampleConfigPath
    Path to the example config file with defaults. Defaults to {ModuleRoot}/config.example.json

    .PARAMETER Force
    Force reload of configuration, bypassing cache.

    .EXAMPLE
    $config = Get-ModuleConfig -ModuleName 'Aspire'

    .EXAMPLE
    $config = Get-ModuleConfig -ModuleName 'Databricks' -SchemaPath "$PSScriptRoot/../Schemas/config.schema.json" -ExampleConfigPath "$PSScriptRoot/../config.example.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter()]
        [string]$SchemaPath,

        [Parameter()]
        [string]$ExampleConfigPath,

        [switch]$Force
    )

    # Cache key for module scope variable
    $cacheKey = "${ModuleName}_Config"

    # Return cached config if available
    if (-not $Force -and (Get-Variable -Name $cacheKey -Scope Script -ErrorAction SilentlyContinue)) {
        return (Get-Variable -Name $cacheKey -Scope Script -ValueOnly)
    }

    # Auto-discover schema and example config paths if not provided
    if (-not $SchemaPath -or -not $ExampleConfigPath) {
        $module = Get-Module -Name $ModuleName -ErrorAction SilentlyContinue
        if (-not $module) {
            $module = Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 1
        }

        if ($module) {
            $moduleRoot = Split-Path $module.Path -Parent

            if (-not $SchemaPath) {
                $SchemaPath = Join-Path $moduleRoot "config.schema.json"
            }
            if (-not $ExampleConfigPath) {
                $ExampleConfigPath = Join-Path $moduleRoot "config.example.json"
            }
        }
        else {
            throw "Module '$ModuleName' not found. Cannot auto-discover schema and example config paths."
        }
    }

    # Validate that schema and example config exist
    if (-not (Test-Path $SchemaPath)) {
        throw "Schema file not found at '$SchemaPath'"
    }
    if (-not (Test-Path $ExampleConfigPath)) {
        throw "Example config not found at '$ExampleConfigPath'"
    }

    # Config path
    $configDir = Join-Path $env:USERPROFILE ".config\$ModuleName"
    $configPath = Join-Path $configDir "config.json"

    # If config doesn't exist, initialize it
    if (-not (Test-Path $configPath)) {
        Write-Warning "Config not found for module '$ModuleName'. Starting interactive setup..."
        Initialize-ModuleConfig -ModuleName $ModuleName -SchemaPath $SchemaPath -ExampleConfigPath $ExampleConfigPath
    }

    # Load config
    try {
        $configContent = Get-Content -Path $configPath -Raw -ErrorAction Stop
        $config = $configContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to load config from '$configPath': $_"
    }

    # Validate against schema
    $validationResult = Test-ConfigSchema -ConfigPath $configPath -SchemaPath $SchemaPath
    if (-not $validationResult.IsValid) {
        throw "Config validation failed for '$ModuleName': $($validationResult.Errors -join ', ')"
    }

    # Cache and return
    Set-Variable -Name $cacheKey -Value $config -Scope Script
    return $config
}
