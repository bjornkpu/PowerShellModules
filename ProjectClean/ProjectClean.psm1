$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
    }
    catch {
        Write-Error "Failed to import private function $($function.FullName): $_"
    }
}

$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
    }
    catch {
        Write-Error "Failed to import public function $($function.FullName): $_"
    }
}

Export-ModuleMember -Function $publicFunctions.BaseName
