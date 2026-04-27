function Export-MachineSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$IncludeStoreApps,
        [switch]$IncludeAllUsersModules,
        [switch]$PinVersions,
        [switch]$Force
    )

    if ((Test-Path -LiteralPath $Path) -and -not $Force) {
        throw "File '$Path' already exists. Use -Force to overwrite."
    }

    Write-Information "Reading current machine state..." -InformationAction Continue

    $winget  = Get-WingetState -IncludeStoreApps:$IncludeStoreApps
    $modules = Get-PSModuleState -IncludeAllUsersModules:$IncludeAllUsersModules
    $repos   = Get-PSRepoState

    $dotnetTools = @()
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        try { $dotnetTools = Get-DotNetToolState } catch { Write-Warning "dotnet tool list failed: $($_.Exception.Message)" }
    }

    $uvTools = @()
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        try { $uvTools = Get-UvToolState } catch { Write-Warning "uv tool list failed: $($_.Exception.Message)" }
    }

    $npmGlobals = @()
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        try { $npmGlobals = Get-NpmGlobalState } catch { Write-Warning "npm ls -g failed: $($_.Exception.Message)" }
    }

    $wingetSpec = foreach ($p in $winget) {
        [pscustomobject]@{
            Id      = $p.Id
            Version = if ($PinVersions) { $p.Version } else { $null }
            Source  = $p.Source
        }
    }

    $modulesSpec = foreach ($m in $modules) {
        [pscustomobject]@{
            Name    = $m.Name
            Version = $m.Version
            Scope   = $m.Scope
        }
    }

    $reposSpec = foreach ($r in $repos) {
        [pscustomobject]@{
            Name           = $r.Name
            Trusted        = $r.Trusted
            SourceLocation = $r.SourceLocation
        }
    }

    $dotnetSpec = foreach ($t in $dotnetTools) {
        [pscustomobject]@{
            Id      = $t.Id
            Version = if ($PinVersions) { $t.Version } else { $null }
        }
    }

    $uvSpec = foreach ($t in $uvTools) {
        [pscustomobject]@{
            Name    = $t.Name
            Version = if ($PinVersions) { $t.Version } else { $null }
        }
    }

    $npmSpec = foreach ($t in $npmGlobals) {
        [pscustomobject]@{
            Name    = $t.Name
            Version = if ($PinVersions) { $t.Version } else { $null }
        }
    }

    $spec = [pscustomobject]@{
        Version      = 1
        Winget       = @($wingetSpec)
        Modules      = @($modulesSpec)
        Repositories = @($reposSpec)
        DotnetTools  = @($dotnetSpec)
        UvTools      = @($uvSpec)
        NpmGlobals   = @($npmSpec)
    }

    Write-Spec -Spec $spec -Path $Path -Force:$Force

    Write-Information ("Exported {0} winget, {1} module(s), {2} repo(s), {3} dotnet tool(s), {4} uv tool(s), {5} npm global(s) to '{6}'." -f `
        @($wingetSpec).Count, @($modulesSpec).Count, @($reposSpec).Count, @($dotnetSpec).Count, @($uvSpec).Count, @($npmSpec).Count, $Path) `
        -InformationAction Continue
}
