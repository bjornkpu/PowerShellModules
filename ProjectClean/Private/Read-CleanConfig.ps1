function ConvertTo-CleanRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Entry
    )

    if ($null -eq $Entry) {
        return $null
    }

    if ($Entry -is [string]) {
        $name = $Entry
        $requires = $null
    }
    else {
        $name = [string]$Entry.name
        $requires = @($Entry.requires)
    }

    if ([string]::IsNullOrWhiteSpace($name)) {
        return $null
    }

    $normalized = $name -replace '\\', '/'
    $hasPathSep = $normalized.Contains('/')
    $hasWildcard = $name -match '[\*\?]'

    if ($hasPathSep) {
        $segments = $normalized.Trim('/').Split('/', [StringSplitOptions]::RemoveEmptyEntries)
        return [pscustomobject]@{
            Kind     = 'Path'
            Pattern  = $name
            Segments = $segments
            Requires = $requires
        }
    }

    $kind = if ($hasWildcard) { 'WildcardName' } else { 'Name' }
    return [pscustomobject]@{
        Kind     = $kind
        Pattern  = $name
        Segments = $null
        Requires = $requires
    }
}

function Get-CleanConfig {
    [CmdletBinding()]
    param()

    $raw = Get-ModuleConfig -ModuleName 'ProjectClean'

    $directoryRules = @()
    foreach ($entry in @($raw.directories)) {
        $rule = ConvertTo-CleanRule -Entry $entry
        if ($rule) { $directoryRules += $rule }
    }

    $fileRules = @()
    foreach ($entry in @($raw.files)) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) {
            $fileRules += [pscustomobject]@{
                Kind    = 'WildcardName'
                Pattern = $entry
            }
        }
    }

    $excludeRules = @()
    foreach ($entry in @($raw.exclude)) {
        $rule = ConvertTo-CleanRule -Entry $entry
        if ($rule) { $excludeRules += $rule }
    }

    $forbiddenRoots = @()
    if ($raw.PSObject.Properties.Name -contains 'forbiddenRoots') {
        $forbiddenRoots = @($raw.forbiddenRoots) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    $rawExcludeStrings = @($raw.exclude) | ForEach-Object {
        if ($_ -is [string]) { $_ } elseif ($_) { [string]$_.name }
    }
    $hasGitExclude = $rawExcludeStrings -contains '.git'

    return [pscustomobject]@{
        Directories    = $directoryRules
        Files          = $fileRules
        Exclude        = $excludeRules
        ForbiddenRoots = $forbiddenRoots
        HasGitExclude  = $hasGitExclude
    }
}
