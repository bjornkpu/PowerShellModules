function Initialize-ModuleConfig {
    <#
    .SYNOPSIS
    Interactively creates a configuration file for a PowerShell module.

    .DESCRIPTION
    Prompts the user for configuration values based on JSON schema definitions.
    Uses defaults from the example config file. Validates input and saves to user's config directory.

    .PARAMETER ModuleName
    Name of the module to configure.

    .PARAMETER SchemaPath
    Path to the JSON schema file.

    .PARAMETER ExampleConfigPath
    Path to the example config file with defaults.

    .EXAMPLE
    Initialize-ModuleConfig -ModuleName 'Databricks' -SchemaPath "./Schemas/config.schema.json" -ExampleConfigPath "./config.example.json"
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

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $ModuleName Module Configuration Setup" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Load schema and example
    try {
        $schema = Get-Content -Path $SchemaPath -Raw | ConvertFrom-Json
        $example = Get-Content -Path $ExampleConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to load schema or example config: $_"
    }

    # Config directory
    $configDir = Join-Path $env:USERPROFILE ".config\$ModuleName"
    $configPath = Join-Path $configDir "config.json"

    # Create directory if needed
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }

    # Build config interactively
    $config = @{}

    function Get-ConfigValue {
        param(
            [string]$PropertyName,
            [object]$SchemaProperty,
            [object]$DefaultValue
        )

        $description = if ($SchemaProperty.description) { $SchemaProperty.description } else { $PropertyName }
        $defaultStr = if ($DefaultValue) { " [$DefaultValue]" } else { "" }

        $prompt = "$description$defaultStr"
        Write-Host $prompt -NoNewline -ForegroundColor Yellow
        Write-Host ": " -NoNewline

        $input = Read-Host

        # Use default if input is empty
        if ([string]::IsNullOrWhiteSpace($input) -and $DefaultValue) {
            return $DefaultValue
        }
        elseif ([string]::IsNullOrWhiteSpace($input)) {
            # Required field with no default
            Write-Host "This field is required. Please provide a value." -ForegroundColor Red
            return Get-ConfigValue -PropertyName $PropertyName -SchemaProperty $SchemaProperty -DefaultValue $DefaultValue
        }

        # Validate pattern if specified
        if ($SchemaProperty.pattern) {
            if ($input -notmatch $SchemaProperty.pattern) {
                Write-Host "Invalid format. Please try again." -ForegroundColor Red
                return Get-ConfigValue -PropertyName $PropertyName -SchemaProperty $SchemaProperty -DefaultValue $DefaultValue
            }
        }

        return $input
    }

    # Process schema properties (assuming flat structure for now)
    foreach ($property in $schema.properties.PSObject.Properties) {
        $propertyName = $property.Name
        $propertySchema = $property.Value

        # Handle nested object (like "databricks": { ... })
        if ($propertySchema.type -eq 'object') {
            $nestedConfig = @{}
            foreach ($nestedProp in $propertySchema.properties.PSObject.Properties) {
                $nestedName = $nestedProp.Name
                $nestedSchema = $nestedProp.Value
                $defaultValue = $example.$propertyName.$nestedName

                $nestedConfig[$nestedName] = Get-ConfigValue -PropertyName $nestedName -SchemaProperty $nestedSchema -DefaultValue $defaultValue
            }
            $config[$propertyName] = $nestedConfig
        }
        else {
            # Simple property
            $defaultValue = $example.$propertyName
            $config[$propertyName] = Get-ConfigValue -PropertyName $propertyName -SchemaProperty $propertySchema -DefaultValue $defaultValue
        }
    }

    # Save config
    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Force
        Write-Host "`nConfiguration saved to: $configPath" -ForegroundColor Green
    }
    catch {
        throw "Failed to save configuration: $_"
    }

    # Validate
    $validationResult = Test-ConfigSchema -ConfigPath $configPath -SchemaPath $SchemaPath
    if (-not $validationResult.IsValid) {
        Write-Host "`nWarning: Configuration validation failed:" -ForegroundColor Red
        $validationResult.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        throw "Config validation failed. Please fix the errors and try again."
    }

    Write-Host "`nConfiguration setup complete!`n" -ForegroundColor Green
}
