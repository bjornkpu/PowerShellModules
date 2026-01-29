function Get-PackageVersionFromPyproject {
    <#
    .SYNOPSIS
    Extracts the package version from pyproject.toml.

    .DESCRIPTION
    Reads the pyproject.toml file from the specified workspace path and package name,
    extracting the version string using regex pattern matching.

    .PARAMETER WorkspacePath
    The workspace root path containing the Python package

    .PARAMETER PackageName
    The name of the Python package subdirectory

    .OUTPUTS
    String version in format "major.minor.patch"

    .EXAMPLE
    $version = Get-PackageVersionFromPyproject -WorkspacePath "C:\repos\myproject" -PackageName "mypackage"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$WorkspacePath,

        [Parameter(Mandatory)]
        [string]$PackageName
    )

    $pyprojectPath = Join-Path $WorkspacePath "$PackageName\pyproject.toml"

    if (-not (Test-Path $pyprojectPath)) {
        throw "pyproject.toml not found at $pyprojectPath"
    }

    $content = Get-Content $pyprojectPath -Raw
    
    if ($content -match 'version\s*=\s*"(\d+\.\d+\.\d+)"') {
        return $matches[1]
    }
    else {
        throw "Could not find version in pyproject.toml at $pyprojectPath"
    }
}
