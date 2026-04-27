function Compare-State {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Spec,
        [Parameter(Mandatory)] $WingetState,
        [Parameter(Mandatory)] $ModuleState,
        [Parameter(Mandatory)] $RepoState,
        $DotnetState = @(),
        $UvState     = @(),
        $NpmState    = @()
    )

    $plan = @()

    foreach ($repo in (@($Spec.Repositories) | Where-Object { $_ })) {
        $current = @($RepoState) | Where-Object { $_.Name -eq $repo.Name } | Select-Object -First 1
        if (-not $current) {
            $plan += [pscustomobject]@{
                Kind        = 'PSRepository'
                Action      = 'Install'
                Id          = $repo.Name
                FromVersion = $null
                ToVersion   = $null
                Reason      = 'not registered'
                Spec        = $repo
            }
        }
        elseif ([bool]$current.Trusted -ne [bool]$repo.Trusted) {
            $plan += [pscustomobject]@{
                Kind        = 'PSRepository'
                Action      = 'Upgrade'
                Id          = $repo.Name
                FromVersion = "trusted=$($current.Trusted)"
                ToVersion   = "trusted=$($repo.Trusted)"
                Reason      = 'trust mismatch'
                Spec        = $repo
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind        = 'PSRepository'
                Action      = 'Skip'
                Id          = $repo.Name
                FromVersion = $null
                ToVersion   = $null
                Reason      = 'already registered'
                Spec        = $repo
            }
        }
    }

    foreach ($pkg in (@($Spec.Winget) | Where-Object { $_ })) {
        $current = @($WingetState) | Where-Object { $_.Id -eq $pkg.Id } | Select-Object -First 1
        if (-not $current) {
            $plan += [pscustomobject]@{
                Kind        = 'WingetPackage'
                Action      = 'Install'
                Id          = $pkg.Id
                FromVersion = $null
                ToVersion   = $pkg.Version
                Reason      = 'not installed'
                Spec        = $pkg
            }
        }
        elseif ($pkg.Version -and $current.Version -ne $pkg.Version) {
            $plan += [pscustomobject]@{
                Kind        = 'WingetPackage'
                Action      = 'Upgrade'
                Id          = $pkg.Id
                FromVersion = $current.Version
                ToVersion   = $pkg.Version
                Reason      = 'version mismatch'
                Spec        = $pkg
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind        = 'WingetPackage'
                Action      = 'Skip'
                Id          = $pkg.Id
                FromVersion = $current.Version
                ToVersion   = $current.Version
                Reason      = if ($pkg.Version) { 'version matches' } else { 'present (latest tracked)' }
                Spec        = $pkg
            }
        }
    }

    foreach ($t in (@($Spec.DotnetTools) | Where-Object { $_ })) {
        $current = @($DotnetState) | Where-Object { $_.Id -eq $t.Id } | Select-Object -First 1
        if (-not $current) {
            $plan += [pscustomobject]@{
                Kind = 'DotNetTool'; Action = 'Install'; Id = $t.Id
                FromVersion = $null; ToVersion = $t.Version
                Reason = 'not installed'; Spec = $t
            }
        }
        elseif ($t.Version -and $current.Version -ne $t.Version) {
            $plan += [pscustomobject]@{
                Kind = 'DotNetTool'; Action = 'Upgrade'; Id = $t.Id
                FromVersion = $current.Version; ToVersion = $t.Version
                Reason = 'version mismatch'; Spec = $t
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind = 'DotNetTool'; Action = 'Skip'; Id = $t.Id
                FromVersion = $current.Version; ToVersion = $current.Version
                Reason = if ($t.Version) { 'version matches' } else { 'present (latest tracked)' }
                Spec = $t
            }
        }
    }

    foreach ($t in (@($Spec.UvTools) | Where-Object { $_ })) {
        $current = @($UvState) | Where-Object { $_.Name -eq $t.Name } | Select-Object -First 1
        if (-not $current) {
            $plan += [pscustomobject]@{
                Kind = 'UvTool'; Action = 'Install'; Id = $t.Name
                FromVersion = $null; ToVersion = $t.Version
                Reason = 'not installed'; Spec = $t
            }
        }
        elseif ($t.Version -and $current.Version -ne $t.Version) {
            $plan += [pscustomobject]@{
                Kind = 'UvTool'; Action = 'Upgrade'; Id = $t.Name
                FromVersion = $current.Version; ToVersion = $t.Version
                Reason = 'version mismatch'; Spec = $t
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind = 'UvTool'; Action = 'Skip'; Id = $t.Name
                FromVersion = $current.Version; ToVersion = $current.Version
                Reason = if ($t.Version) { 'version matches' } else { 'present (latest tracked)' }
                Spec = $t
            }
        }
    }

    foreach ($t in (@($Spec.NpmGlobals) | Where-Object { $_ })) {
        $current = @($NpmState) | Where-Object { $_.Name -eq $t.Name } | Select-Object -First 1
        if (-not $current) {
            $plan += [pscustomobject]@{
                Kind = 'NpmGlobal'; Action = 'Install'; Id = $t.Name
                FromVersion = $null; ToVersion = $t.Version
                Reason = 'not installed'; Spec = $t
            }
        }
        elseif ($t.Version -and $current.Version -ne $t.Version) {
            $plan += [pscustomobject]@{
                Kind = 'NpmGlobal'; Action = 'Upgrade'; Id = $t.Name
                FromVersion = $current.Version; ToVersion = $t.Version
                Reason = 'version mismatch'; Spec = $t
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind = 'NpmGlobal'; Action = 'Skip'; Id = $t.Name
                FromVersion = $current.Version; ToVersion = $current.Version
                Reason = if ($t.Version) { 'version matches' } else { 'present (latest tracked)' }
                Spec = $t
            }
        }
    }

    foreach ($mod in (@($Spec.Modules) | Where-Object { $_ })) {
        $current = @($ModuleState) | Where-Object { $_.Name -eq $mod.Name } | Select-Object -First 1
        if (-not $current) {
            $plan += [pscustomobject]@{
                Kind        = 'PSModule'
                Action      = 'Install'
                Id          = $mod.Name
                FromVersion = $null
                ToVersion   = $mod.Version
                Reason      = 'not installed'
                Spec        = $mod
            }
        }
        elseif ($mod.Version -and $current.Version -ne $mod.Version) {
            $plan += [pscustomobject]@{
                Kind        = 'PSModule'
                Action      = 'Upgrade'
                Id          = $mod.Name
                FromVersion = $current.Version
                ToVersion   = $mod.Version
                Reason      = 'version mismatch'
                Spec        = $mod
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind        = 'PSModule'
                Action      = 'Skip'
                Id          = $mod.Name
                FromVersion = $current.Version
                ToVersion   = $current.Version
                Reason      = if ($mod.Version) { 'version matches' } else { 'present (latest tracked)' }
                Spec        = $mod
            }
        }
    }

    ,$plan
}
