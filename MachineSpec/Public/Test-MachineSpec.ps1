function Test-MachineSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$Quiet
    )

    $spec = Read-Spec -Path $Path

    $wingetState = Get-WingetState
    $moduleState = Get-PSModuleState -IncludeAllUsersModules
    $repoState   = Get-PSRepoState

    $dotnetState = if (@($spec.DotnetTools).Count -gt 0 -and (Get-Command dotnet -ErrorAction SilentlyContinue)) { Get-DotNetToolState } else { @() }
    $uvState     = if (@($spec.UvTools).Count     -gt 0 -and (Get-Command uv     -ErrorAction SilentlyContinue)) { Get-UvToolState }     else { @() }
    $npmState    = if (@($spec.NpmGlobals).Count  -gt 0 -and (Get-Command npm    -ErrorAction SilentlyContinue)) { Get-NpmGlobalState }  else { @() }

    $plan = Compare-State -Spec $spec `
        -WingetState $wingetState -ModuleState $moduleState -RepoState $repoState `
        -DotnetState $dotnetState -UvState $uvState -NpmState $npmState

    if (-not $Quiet) {
        $byAction = @($plan) | Group-Object Action | Sort-Object Name
        $summary = ($byAction | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join '  '
        Write-Information "Drift: $summary" -InformationAction Continue
        $actionable = @($plan) | Where-Object { $_.Action -ne 'Skip' }
        if ($actionable.Count -gt 0) {
            $table = $actionable | Format-Table -Property Action, Kind, Id, FromVersion, ToVersion, Reason -AutoSize | Out-String
            Write-Information $table.TrimEnd() -InformationAction Continue
        }
    }

    $plan

    if (@($plan) | Where-Object { $_.Action -ne 'Skip' }) {
        $global:LASTEXITCODE = 1
    }
    else {
        $global:LASTEXITCODE = 0
    }
}
