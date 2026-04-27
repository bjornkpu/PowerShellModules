function Install-MachineSpec {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$SkipWinget,
        [switch]$SkipPowerShell,
        [switch]$SkipDotnet,
        [switch]$SkipUv,
        [switch]$SkipNpm,
        [switch]$ContinueOnError,
        [switch]$Quiet
    )

    $spec = Read-Spec -Path $Path

    $needsAllUsers = @($spec.Modules) | Where-Object { $_.Scope -eq 'AllUsers' }
    if ($needsAllUsers -and -not (Test-Elevation)) {
        throw "Spec requires AllUsers module installs. Re-run as Administrator. Offending modules: $(($needsAllUsers.Name) -join ', ')"
    }

    if (-not $SkipDotnet -and @($spec.DotnetTools).Count -gt 0 -and -not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw "Spec lists dotnet tools but 'dotnet' is not on PATH. Install the .NET SDK first (e.g. winget install Microsoft.DotNet.SDK)."
    }
    if (-not $SkipUv -and @($spec.UvTools).Count -gt 0 -and -not (Get-Command uv -ErrorAction SilentlyContinue)) {
        throw "Spec lists uv tools but 'uv' is not on PATH. Install uv first (e.g. winget install astral-sh.uv)."
    }
    if (-not $SkipNpm -and @($spec.NpmGlobals).Count -gt 0 -and -not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "Spec lists npm globals but 'npm' is not on PATH. Install Node.js first."
    }

    $wingetState = if ($SkipWinget)     { @() } else { Get-WingetState }
    $moduleState = if ($SkipPowerShell) { @() } else { Get-PSModuleState -IncludeAllUsersModules }
    $repoState   = if ($SkipPowerShell) { @() } else { Get-PSRepoState }
    $dotnetState = if ($SkipDotnet -or @($spec.DotnetTools).Count -eq 0) { @() } else { Get-DotNetToolState }
    $uvState     = if ($SkipUv     -or @($spec.UvTools).Count     -eq 0) { @() } else { Get-UvToolState }
    $npmState    = if ($SkipNpm    -or @($spec.NpmGlobals).Count  -eq 0) { @() } else { Get-NpmGlobalState }

    $effectiveSpec = [pscustomobject]@{
        Winget       = if ($SkipWinget)     { @() } else { @($spec.Winget) }
        Modules      = if ($SkipPowerShell) { @() } else { @($spec.Modules) }
        Repositories = if ($SkipPowerShell) { @() } else { @($spec.Repositories) }
        DotnetTools  = if ($SkipDotnet)     { @() } else { @($spec.DotnetTools) }
        UvTools      = if ($SkipUv)         { @() } else { @($spec.UvTools) }
        NpmGlobals   = if ($SkipNpm)        { @() } else { @($spec.NpmGlobals) }
    }

    $plan = Compare-State -Spec $effectiveSpec `
        -WingetState $wingetState -ModuleState $moduleState -RepoState $repoState `
        -DotnetState $dotnetState -UvState $uvState -NpmState $npmState

    if (-not $Quiet) {
        Write-PlanSummary -Plan $plan
    }

    $actionable = @($plan) | Where-Object { $_.Action -ne 'Skip' }
    if ($actionable.Count -eq 0) {
        if (-not $Quiet) { Write-Information "Nothing to do; machine matches spec." -InformationAction Continue }
        return $plan
    }

    if (-not $PSCmdlet.ShouldProcess($Path, "Apply $($actionable.Count) change(s)")) {
        return $plan
    }

    $errors = @()
    $orderedKinds = @('PSRepository', 'WingetPackage', 'PSModule', 'DotNetTool', 'UvTool', 'NpmGlobal')
    foreach ($kind in $orderedKinds) {
        foreach ($step in @($plan) | Where-Object { $_.Kind -eq $kind -and $_.Action -ne 'Skip' }) {
            try {
                $result = Invoke-PlanStep -Step $step
                $result
            }
            catch {
                $err = [pscustomobject]@{
                    Kind   = $step.Kind
                    Action = 'Failed'
                    Id     = $step.Id
                    Error  = $_.Exception.Message
                    Step   = $step
                }
                $errors += $err
                $err
                if (-not $ContinueOnError) {
                    Write-Error "Aborting after failure on $($step.Kind) '$($step.Id)': $($_.Exception.Message)"
                    return
                }
                Write-Warning "Failed $($step.Kind) '$($step.Id)': $($_.Exception.Message); continuing."
            }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Error "Install completed with $($errors.Count) error(s)."
    }
}

function Write-PlanSummary {
    param($Plan)

    $byAction = @($Plan) | Group-Object Action | Sort-Object Name
    $summary = ($byAction | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join '  '
    Write-Information "Plan: $summary" -InformationAction Continue

    $actionable = @($Plan) | Where-Object { $_.Action -ne 'Skip' }
    if ($actionable.Count -gt 0) {
        $table = $actionable | Format-Table -Property Action, Kind, Id, FromVersion, ToVersion, Reason -AutoSize | Out-String
        Write-Information $table.TrimEnd() -InformationAction Continue
    }
}

function Invoke-PlanStep {
    param($Step)

    switch ($Step.Kind) {
        'PSRepository' {
            $repo = $Step.Spec
            $policy = if ($repo.Trusted) { 'Trusted' } else { 'Untrusted' }
            if ($Step.Action -eq 'Install') {
                if (-not $repo.SourceLocation) {
                    if ($repo.Name -eq 'PSGallery') {
                        Set-PSRepository -Name 'PSGallery' -InstallationPolicy $policy
                    }
                    else {
                        throw "Repository '$($repo.Name)' has no sourceLocation; cannot register."
                    }
                }
                else {
                    Register-PSRepository -Name $repo.Name -SourceLocation $repo.SourceLocation -InstallationPolicy $policy
                }
            }
            else {
                Set-PSRepository -Name $repo.Name -InstallationPolicy $policy
            }
        }
        'WingetPackage' {
            $pkg = $Step.Spec
            $cmdArgs = @('install', '--id', $pkg.Id, '--exact', '--accept-package-agreements', '--accept-source-agreements', '--silent')
            if ($pkg.Version) { $cmdArgs += @('--version', $pkg.Version) }
            if ($pkg.Source)  { $cmdArgs += @('--source', $pkg.Source) }

            $proc = Start-Process -FilePath 'winget' -ArgumentList $cmdArgs -NoNewWindow -Wait -PassThru
            if ($proc.ExitCode -ne 0) {
                throw "winget install '$($pkg.Id)' exited $($proc.ExitCode)."
            }
        }
        'PSModule' {
            $mod = $Step.Spec
            $params = @{
                Name         = $mod.Name
                Scope        = $mod.Scope
                Force        = $true
                AllowClobber = $true
                ErrorAction  = 'Stop'
            }
            if ($mod.Version) { $params['RequiredVersion'] = $mod.Version }
            Install-Module @params
        }
        'DotNetTool' {
            $t = $Step.Spec
            $verb = if ($Step.Action -eq 'Upgrade') { 'update' } else { 'install' }
            $cmdArgs = @('tool', $verb, '--global', $t.Id)
            if ($t.Version) { $cmdArgs += @('--version', $t.Version) }
            $out = & dotnet @cmdArgs 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "dotnet tool $verb '$($t.Id)' exited $LASTEXITCODE`: $($out -join "`n")"
            }
        }
        'UvTool' {
            $t = $Step.Spec
            $pkgSpec = if ($t.Version) { "$($t.Name)==$($t.Version)" } else { $t.Name }
            $cmdArgs = @('tool', 'install', $pkgSpec)
            if ($Step.Action -eq 'Upgrade') { $cmdArgs += '--reinstall' }
            $out = & uv @cmdArgs 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "uv tool install '$pkgSpec' exited $LASTEXITCODE`: $($out -join "`n")"
            }
        }
        'NpmGlobal' {
            $t = $Step.Spec
            $pkgSpec = if ($t.Version) { "$($t.Name)@$($t.Version)" } else { $t.Name }
            $out = & npm install -g $pkgSpec 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "npm install -g '$pkgSpec' exited $LASTEXITCODE`: $($out -join "`n")"
            }
        }
        default {
            throw "Unknown plan step kind: $($Step.Kind)"
        }
    }

    [pscustomobject]@{
        Kind        = $Step.Kind
        Action      = $Step.Action
        Id          = $Step.Id
        FromVersion = $Step.FromVersion
        ToVersion   = $Step.ToVersion
        Status      = 'Succeeded'
    }
}
