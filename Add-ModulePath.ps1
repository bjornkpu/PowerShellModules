<#
.SYNOPSIS
Adds the PowerShellModules directory to PSModulePath.

.DESCRIPTION
Adds the current directory (PowerShellModules) to the User-level PSModulePath
environment variable if it's not already present. This allows PowerShell to
discover and import modules from this repository.

.EXAMPLE
.\Add-ModulePath.ps1
Adds the PowerShellModules directory to PSModulePath
#>

$modulePath = $PSScriptRoot

# Check if already in PSModulePath
if ($env:PSModulePath -like "*$modulePath*") {
    Write-Host "✓ Module path already configured: $modulePath" -ForegroundColor Green
    Write-Host "Current PSModulePath entries:" -ForegroundColor Cyan
    $env:PSModulePath -split ';' | Where-Object { $_ } | ForEach-Object { Write-Host "  - $_" }
    exit 0
}

# Add to User-level PSModulePath
Write-Host "Adding module path: $modulePath" -ForegroundColor Cyan

try {
    $currentPath = [Environment]::GetEnvironmentVariable('PSModulePath', 'User')
    $newPath = if ($currentPath) {
        "$currentPath;$modulePath"
    }
    else {
        $modulePath
    }

    [Environment]::SetEnvironmentVariable('PSModulePath', $newPath, 'User')

    # Update current session
    $env:PSModulePath = "$env:PSModulePath;$modulePath"

    Write-Host "✓ Module path added successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now import modules with:" -ForegroundColor Yellow
    Write-Host "  Import-Module Databricks" -ForegroundColor White
    Write-Host "  Import-Module WireGuard" -ForegroundColor White
    Write-Host "  Import-Module ProjectManager" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: Restart PowerShell or reload your profile for this to take effect in new sessions." -ForegroundColor Yellow
}
catch {
    Write-Host "✗ Failed to add module path: $_" -ForegroundColor Red
    exit 1
}
