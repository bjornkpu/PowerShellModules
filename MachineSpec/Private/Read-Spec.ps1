function Read-Spec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Spec file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $doc = ConvertFrom-Yaml -Yaml $raw -Ordered
    }
    catch {
        throw "YAML parse error in '$Path': $($_.Exception.Message)"
    }

    if ($null -eq $doc) {
        $doc = [ordered]@{}
    }
    elseif ($doc -isnot [System.Collections.IDictionary]) {
        throw "Spec root must be a mapping in '$Path'."
    }

    if (-not $doc.Contains('version')) {
        throw "Spec '$Path' is missing required root key 'version'."
    }
    if ($doc['version'] -ne 1) {
        throw "Unsupported spec version $($doc['version']) in '$Path' (expected 1)."
    }

    $known = @('version', 'winget', 'powershell', 'dotnet', 'uv', 'npm')
    foreach ($key in $doc.Keys) {
        if ($key -notin $known) {
            Write-Warning "Unknown root key '$key' in '$Path' (ignored)."
        }
    }

    $wingetPackages = @()
    if ($doc.Contains('winget') -and $doc['winget'] -is [System.Collections.IDictionary] -and $doc['winget'].Contains('packages')) {
        foreach ($entry in @($doc['winget']['packages'])) {
            $wingetPackages += (ConvertTo-WingetEntry $entry)
        }
    }

    $modules = @()
    $repositories = @()
    if ($doc.Contains('powershell') -and $doc['powershell'] -is [System.Collections.IDictionary]) {
        $ps = $doc['powershell']
        if ($ps.Contains('modules')) {
            foreach ($entry in @($ps['modules'])) {
                $modules += (ConvertTo-ModuleEntry $entry)
            }
        }
        if ($ps.Contains('repositories')) {
            foreach ($entry in @($ps['repositories'])) {
                $repositories += (ConvertTo-RepoEntry $entry)
            }
        }
    }

    $dotnetTools = @()
    if ($doc.Contains('dotnet') -and $doc['dotnet'] -is [System.Collections.IDictionary] -and $doc['dotnet'].Contains('tools')) {
        foreach ($entry in @($doc['dotnet']['tools'])) {
            $dotnetTools += (ConvertTo-DotnetEntry $entry)
        }
    }

    $uvTools = @()
    if ($doc.Contains('uv') -and $doc['uv'] -is [System.Collections.IDictionary] -and $doc['uv'].Contains('tools')) {
        foreach ($entry in @($doc['uv']['tools'])) {
            $uvTools += (ConvertTo-UvEntry $entry)
        }
    }

    $npmGlobals = @()
    if ($doc.Contains('npm') -and $doc['npm'] -is [System.Collections.IDictionary] -and $doc['npm'].Contains('globals')) {
        foreach ($entry in @($doc['npm']['globals'])) {
            $npmGlobals += (ConvertTo-NpmEntry $entry)
        }
    }

    [pscustomobject]@{
        Version      = 1
        Winget       = $wingetPackages
        Modules      = $modules
        Repositories = $repositories
        DotnetTools  = $dotnetTools
        UvTools      = $uvTools
        NpmGlobals   = $npmGlobals
        SourcePath   = (Resolve-Path -LiteralPath $Path).Path
    }
}

function ConvertTo-WingetEntry {
    param($Entry)

    if ($Entry -is [string]) {
        return [pscustomobject]@{
            Id      = $Entry
            Version = $null
            Source  = 'winget'
        }
    }
    if ($Entry -is [System.Collections.IDictionary]) {
        if (-not $Entry.Contains('id') -or [string]::IsNullOrWhiteSpace([string]$Entry['id'])) {
            throw "winget package entry missing required 'id': $(ConvertTo-Json $Entry -Compress)"
        }
        return [pscustomobject]@{
            Id      = [string]$Entry['id']
            Version = if ($Entry.Contains('version')) { [string]$Entry['version'] } else { $null }
            Source  = if ($Entry.Contains('source') -and -not [string]::IsNullOrWhiteSpace([string]$Entry['source'])) { [string]$Entry['source'] } else { 'winget' }
        }
    }
    throw "Unrecognized winget entry shape: $Entry"
}

function ConvertTo-ModuleEntry {
    param($Entry)

    if ($Entry -is [string]) {
        return [pscustomobject]@{
            Name    = $Entry
            Version = $null
            Scope   = 'CurrentUser'
        }
    }
    if ($Entry -is [System.Collections.IDictionary]) {
        if (-not $Entry.Contains('name') -or [string]::IsNullOrWhiteSpace([string]$Entry['name'])) {
            throw "powershell.module entry missing required 'name': $(ConvertTo-Json $Entry -Compress)"
        }
        $scope = if ($Entry.Contains('scope') -and -not [string]::IsNullOrWhiteSpace([string]$Entry['scope'])) { [string]$Entry['scope'] } else { 'CurrentUser' }
        if ($scope -notin @('CurrentUser', 'AllUsers')) {
            throw "module '$($Entry['name'])' has invalid scope '$scope' (allowed: CurrentUser, AllUsers)."
        }
        return [pscustomobject]@{
            Name    = [string]$Entry['name']
            Version = if ($Entry.Contains('version')) { [string]$Entry['version'] } else { $null }
            Scope   = $scope
        }
    }
    throw "Unrecognized module entry shape: $Entry"
}

function ConvertTo-DotnetEntry {
    param($Entry)

    if ($Entry -is [string]) {
        return [pscustomobject]@{
            Id      = $Entry
            Version = $null
        }
    }
    if ($Entry -is [System.Collections.IDictionary]) {
        if (-not $Entry.Contains('id') -or [string]::IsNullOrWhiteSpace([string]$Entry['id'])) {
            throw "dotnet.tool entry missing required 'id': $(ConvertTo-Json $Entry -Compress)"
        }
        return [pscustomobject]@{
            Id      = [string]$Entry['id']
            Version = if ($Entry.Contains('version')) { [string]$Entry['version'] } else { $null }
        }
    }
    throw "Unrecognized dotnet.tool entry shape: $Entry"
}

function ConvertTo-UvEntry {
    param($Entry)

    if ($Entry -is [string]) {
        return [pscustomobject]@{
            Name    = $Entry
            Version = $null
        }
    }
    if ($Entry -is [System.Collections.IDictionary]) {
        if (-not $Entry.Contains('name') -or [string]::IsNullOrWhiteSpace([string]$Entry['name'])) {
            throw "uv.tool entry missing required 'name': $(ConvertTo-Json $Entry -Compress)"
        }
        return [pscustomobject]@{
            Name    = [string]$Entry['name']
            Version = if ($Entry.Contains('version')) { [string]$Entry['version'] } else { $null }
        }
    }
    throw "Unrecognized uv.tool entry shape: $Entry"
}

function ConvertTo-NpmEntry {
    param($Entry)

    if ($Entry -is [string]) {
        return [pscustomobject]@{
            Name    = $Entry
            Version = $null
        }
    }
    if ($Entry -is [System.Collections.IDictionary]) {
        if (-not $Entry.Contains('name') -or [string]::IsNullOrWhiteSpace([string]$Entry['name'])) {
            throw "npm.global entry missing required 'name': $(ConvertTo-Json $Entry -Compress)"
        }
        return [pscustomobject]@{
            Name    = [string]$Entry['name']
            Version = if ($Entry.Contains('version')) { [string]$Entry['version'] } else { $null }
        }
    }
    throw "Unrecognized npm.global entry shape: $Entry"
}

function ConvertTo-RepoEntry {
    param($Entry)

    if ($Entry -is [string]) {
        return [pscustomobject]@{
            Name           = $Entry
            Trusted        = $true
            SourceLocation = $null
        }
    }
    if ($Entry -is [System.Collections.IDictionary]) {
        if (-not $Entry.Contains('name') -or [string]::IsNullOrWhiteSpace([string]$Entry['name'])) {
            throw "powershell.repository entry missing required 'name': $(ConvertTo-Json $Entry -Compress)"
        }
        return [pscustomobject]@{
            Name           = [string]$Entry['name']
            Trusted        = if ($Entry.Contains('trusted')) { [bool]$Entry['trusted'] } else { $true }
            SourceLocation = if ($Entry.Contains('sourceLocation')) { [string]$Entry['sourceLocation'] } else { $null }
        }
    }
    throw "Unrecognized repository entry shape: $Entry"
}
