function Get-ProjectName {
    <#
    .SYNOPSIS
    Extract project name from pyproject.toml for source path derivation
    #>
    [CmdletBinding()]
    param()

    $pyprojectPath = "pyproject.toml"

    if (-not (Test-Path $pyprojectPath)) {
        Write-Verbose "No pyproject.toml found, using directory name"
        return (Split-Path (Get-Location) -Leaf)
    }

    try {
        $content = Get-Content $pyprojectPath -Raw -ErrorAction Stop

        # Try to extract project name
        if ($content -match '(?m)^\[project\][\s\S]*?name\s*=\s*"([^"]+)"') {
            Write-Verbose "Found project name: $($matches[1])"
            return $matches[1]
        }

        # Fallback: Try name before [project] section (for older format)
        if ($content -match 'name\s*=\s*"([^"]+)"') {
            Write-Verbose "Found project name (fallback): $($matches[1])"
            return $matches[1]
        }
    }
    catch {
        Write-Warning "Failed to parse pyproject.toml: $_"
    }

    # Final fallback: use directory name
    $dirName = Split-Path (Get-Location) -Leaf
    Write-Verbose "Using directory name as fallback: $dirName"
    return $dirName
}
