function Get-PSRepoState {
    [CmdletBinding()]
    param()

    $repos = @()
    foreach ($r in @(Get-PSRepository -ErrorAction SilentlyContinue)) {
        $repos += [pscustomobject]@{
            Name           = $r.Name
            Trusted        = ($r.InstallationPolicy -eq 'Trusted')
            SourceLocation = $r.SourceLocation
        }
    }
    ,$repos
}
