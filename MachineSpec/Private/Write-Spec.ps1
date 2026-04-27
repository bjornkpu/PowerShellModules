function Write-Spec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Spec,
        [Parameter(Mandatory)][string]$Path,
        [switch]$Force
    )

    if ((Test-Path -LiteralPath $Path) -and -not $Force) {
        throw "File '$Path' already exists. Use -Force to overwrite."
    }

    $doc = [ordered]@{ version = 1 }

    $wingetItems = @()
    foreach ($pkg in (@($Spec.Winget) | Sort-Object Id)) {
        $entry = [ordered]@{ id = $pkg.Id }
        if ($pkg.Version) { $entry['version'] = $pkg.Version }
        if ($pkg.Source -and $pkg.Source -ne 'winget') { $entry['source'] = $pkg.Source }
        $wingetItems += $entry
    }
    if ($wingetItems.Count -gt 0) {
        $doc['winget'] = [ordered]@{ packages = $wingetItems }
    }

    $repoItems = @()
    foreach ($repo in (@($Spec.Repositories) | Sort-Object Name)) {
        $entry = [ordered]@{ name = $repo.Name; trusted = [bool]$repo.Trusted }
        if ($repo.SourceLocation) { $entry['sourceLocation'] = $repo.SourceLocation }
        $repoItems += $entry
    }

    $moduleItems = @()
    foreach ($mod in (@($Spec.Modules) | Sort-Object Name)) {
        $entry = [ordered]@{ name = $mod.Name }
        if ($mod.Version) { $entry['version'] = $mod.Version }
        if ($mod.Scope -and $mod.Scope -ne 'CurrentUser') { $entry['scope'] = $mod.Scope }
        $moduleItems += $entry
    }

    if ($repoItems.Count -gt 0 -or $moduleItems.Count -gt 0) {
        $ps = [ordered]@{}
        if ($repoItems.Count -gt 0)   { $ps['repositories'] = $repoItems }
        if ($moduleItems.Count -gt 0) { $ps['modules']      = $moduleItems }
        $doc['powershell'] = $ps
    }

    $dotnetItems = @()
    foreach ($t in (@($Spec.DotnetTools) | Sort-Object Id)) {
        $entry = [ordered]@{ id = $t.Id }
        if ($t.Version) { $entry['version'] = $t.Version }
        $dotnetItems += $entry
    }
    if ($dotnetItems.Count -gt 0) {
        $doc['dotnet'] = [ordered]@{ tools = $dotnetItems }
    }

    $uvItems = @()
    foreach ($t in (@($Spec.UvTools) | Sort-Object Name)) {
        $entry = [ordered]@{ name = $t.Name }
        if ($t.Version) { $entry['version'] = $t.Version }
        $uvItems += $entry
    }
    if ($uvItems.Count -gt 0) {
        $doc['uv'] = [ordered]@{ tools = $uvItems }
    }

    $npmItems = @()
    foreach ($t in (@($Spec.NpmGlobals) | Sort-Object Name)) {
        $entry = [ordered]@{ name = $t.Name }
        if ($t.Version) { $entry['version'] = $t.Version }
        $npmItems += $entry
    }
    if ($npmItems.Count -gt 0) {
        $doc['npm'] = [ordered]@{ globals = $npmItems }
    }

    $yaml = ConvertTo-Yaml $doc
    Set-Content -LiteralPath $Path -Value $yaml -Encoding UTF8 -NoNewline:$false
}
