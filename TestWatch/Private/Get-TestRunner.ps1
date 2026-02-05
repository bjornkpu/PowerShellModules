function Get-TestRunner {
    <#
    .SYNOPSIS
    Auto-detect test runner (UV or Poetry) from lock files
    #>
    [CmdletBinding()]
    param()

    # Check for lock files
    if (Test-Path "uv.lock") {
        return "uv run pytest"
    }

    if (Test-Path "poetry.lock") {
        return "poetry run pytest"
    }

    # Fallback to plain pytest
    return "pytest"
}
