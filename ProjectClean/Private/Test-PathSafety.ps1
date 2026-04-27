function Get-NormalizedSafetyPath {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }

    # Drive-relative form like "C:" must be promoted to "C:\" before GetFullPath,
    # otherwise .NET resolves it against the current directory on that drive.
    $p = $Path
    if ($p -match '^[A-Za-z]:$') { $p = "$p\" }

    try {
        return [IO.Path]::GetFullPath($p).TrimEnd('\', '/')
    }
    catch {
        return $null
    }
}

function Test-PathSafety {
    <#
    .SYNOPSIS
    Refuses paths that resolve to dangerous roots.

    .DESCRIPTION
    Throws a terminating error if Path equals any of the hardcoded forbidden roots
    (drive root of the input, USERPROFILE, Documents) or any path in ExtraForbidden.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string[]]$ExtraForbidden = @()
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path not found: $Path"
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $resolvedNorm = Get-NormalizedSafetyPath $resolved

    $forbidden = @(
        [IO.Path]::GetPathRoot($resolved)
        $env:USERPROFILE
        [Environment]::GetFolderPath('MyDocuments')
    )
    if ($ExtraForbidden) {
        $forbidden += $ExtraForbidden
    }

    foreach ($f in $forbidden) {
        $fn = Get-NormalizedSafetyPath $f
        if (-not $fn) { continue }
        if ([string]::Equals($resolvedNorm, $fn, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean forbidden root: $resolvedNorm"
        }
    }
}
