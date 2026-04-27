function Get-PSModuleState {
    [CmdletBinding()]
    param(
        [switch]$IncludeAllUsersModules
    )

    $userPath    = [System.IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'), 'PowerShell', 'Modules')
    $userPathV5  = [System.IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'), 'WindowsPowerShell', 'Modules')
    $allUsers    = "$env:ProgramFiles\PowerShell\Modules"
    $allUsersV5  = "$env:ProgramFiles\WindowsPowerShell\Modules"

    $userPaths    = @($userPath, $userPathV5) | Where-Object { Test-Path -LiteralPath $_ }
    $allUserPaths = @($allUsers, $allUsersV5) | Where-Object { Test-Path -LiteralPath $_ }

    $modules = @()
    foreach ($m in @(Get-InstalledModule -ErrorAction SilentlyContinue)) {
        $scope = if ($userPaths.Where({ $m.InstalledLocation -like "$_*" }, 'First').Count -gt 0) {
            'CurrentUser'
        }
        elseif ($allUserPaths.Where({ $m.InstalledLocation -like "$_*" }, 'First').Count -gt 0) {
            'AllUsers'
        }
        else {
            'Unknown'
        }
        if (-not $IncludeAllUsersModules -and $scope -ne 'CurrentUser') { continue }

        $modules += [pscustomobject]@{
            Name    = $m.Name
            Version = $m.Version.ToString()
            Scope   = $scope
        }
    }

    ,$modules
}
