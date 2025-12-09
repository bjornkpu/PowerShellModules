function Test-ConfigSchema {
    <#
    .SYNOPSIS
    Validates a JSON config file against a JSON schema.

    .DESCRIPTION
    Tests whether a configuration file conforms to its JSON schema.
    Returns validation result with errors if any.

    .PARAMETER ConfigPath
    Path to the configuration JSON file.

    .PARAMETER SchemaPath
    Path to the JSON schema file.

    .EXAMPLE
    $result = Test-ConfigSchema -ConfigPath "~/.config/Databricks/config.json" -SchemaPath "./config.schema.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter(Mandatory)]
        [string]$SchemaPath
    )

    if (-not (Test-Path $ConfigPath)) {
        return @{
            IsValid = $false
            Errors  = @("Config file not found: $ConfigPath")
        }
    }

    if (-not (Test-Path $SchemaPath)) {
        return @{
            IsValid = $false
            Errors  = @("Schema file not found: $SchemaPath")
        }
    }

    try {
        $configContent = Get-Content -Path $ConfigPath -Raw
        $schemaContent = Get-Content -Path $SchemaPath -Raw

        # Test JSON validity with schema
        $isValid = Test-Json -Json $configContent -SchemaFile $SchemaPath -ErrorAction SilentlyContinue

        if ($isValid) {
            # Additional validation: check for placeholder values
            $config = $configContent | ConvertFrom-Json
            $placeholderErrors = @()

            # Recursively check for <placeholder> patterns
            function Test-Placeholders {
                param($obj, $path = "")

                if ($obj -is [string]) {
                    if ($obj -match '^<.*>$') {
                        $placeholderErrors += "Placeholder value found at '$path': $obj"
                    }
                }
                elseif ($obj -is [PSCustomObject]) {
                    $obj.PSObject.Properties | ForEach-Object {
                        $newPath = if ($path) { "$path.$($_.Name)" } else { $_.Name }
                        Test-Placeholders -obj $_.Value -path $newPath
                    }
                }
                elseif ($obj -is [Array]) {
                    for ($i = 0; $i -lt $obj.Count; $i++) {
                        Test-Placeholders -obj $obj[$i] -path "${path}[$i]"
                    }
                }
            }

            Test-Placeholders -obj $config

            if ($placeholderErrors.Count -gt 0) {
                return @{
                    IsValid = $false
                    Errors  = $placeholderErrors
                }
            }

            return @{
                IsValid = $true
                Errors  = @()
            }
        }
        else {
            return @{
                IsValid = $false
                Errors  = @("JSON schema validation failed. Check your config against the schema.")
            }
        }
    }
    catch {
        return @{
            IsValid = $false
            Errors  = @("Validation error: $_")
        }
    }
}
