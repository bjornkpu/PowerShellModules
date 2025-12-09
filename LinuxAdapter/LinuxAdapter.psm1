# Get public function files
$publicFunctions = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
    }
    catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Export public functions and aliases
Export-ModuleMember -Function $publicFunctions.BaseName
Export-ModuleMember -Alias *
