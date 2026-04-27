function Test-CleanNameMatch {
    [CmdletBinding()]
    param(
        [string]$Pattern,
        [string]$Name,
        [bool]$Wildcard
    )

    if ($Wildcard) {
        return [WildcardPattern]::Get($Pattern, 'IgnoreCase').IsMatch($Name)
    }
    return [string]::Equals($Pattern, $Name, [StringComparison]::OrdinalIgnoreCase)
}

function Test-CleanPathMatch {
    [CmdletBinding()]
    param(
        [string[]]$Pattern,
        [string[]]$Actual
    )

    $i = 0
    $j = 0
    $starI = -1
    $starJ = -1

    while ($j -lt $Actual.Count) {
        if ($i -lt $Pattern.Count -and $Pattern[$i] -eq '**') {
            $starI = $i
            $starJ = $j
            $i++
        }
        elseif ($i -lt $Pattern.Count -and [WildcardPattern]::Get($Pattern[$i], 'IgnoreCase').IsMatch($Actual[$j])) {
            $i++
            $j++
        }
        elseif ($starI -ne -1) {
            $i = $starI + 1
            $starJ++
            $j = $starJ
        }
        else {
            return $false
        }
    }

    while ($i -lt $Pattern.Count -and $Pattern[$i] -eq '**') {
        $i++
    }
    return $i -eq $Pattern.Count
}

function Test-CleanRuleMatch {
    [CmdletBinding()]
    param(
        $Rule,
        [string[]]$Segments
    )

    if ($Segments.Count -eq 0) { return $false }

    switch ($Rule.Kind) {
        'Name' {
            return (Test-CleanNameMatch -Pattern $Rule.Pattern -Name $Segments[-1] -Wildcard $false)
        }
        'WildcardName' {
            return (Test-CleanNameMatch -Pattern $Rule.Pattern -Name $Segments[-1] -Wildcard $true)
        }
        'Path' {
            return (Test-CleanPathMatch -Pattern $Rule.Segments -Actual $Segments)
        }
    }
    return $false
}

function Test-CleanAnyRuleMatch {
    [CmdletBinding()]
    param(
        [object[]]$Rules,
        [string[]]$Segments
    )

    foreach ($rule in $Rules) {
        if (Test-CleanRuleMatch -Rule $rule -Segments $Segments) { return $true }
    }
    return $false
}

function Find-CleanDirectoryMatch {
    [CmdletBinding()]
    param(
        [object[]]$Rules,
        [string[]]$Segments,
        [string]$Current
    )

    foreach ($rule in $Rules) {
        if (-not (Test-CleanRuleMatch -Rule $rule -Segments $Segments)) { continue }

        if ($rule.Requires) {
            $parent = Split-Path -Parent $Current
            $satisfied = $false
            try {
                $siblings = Get-ChildItem -LiteralPath $parent -File -Force -ErrorAction Stop
            }
            catch {
                $siblings = @()
            }
            foreach ($pat in $rule.Requires) {
                $wp = [WildcardPattern]::Get($pat, 'IgnoreCase')
                foreach ($s in $siblings) {
                    if ($wp.IsMatch($s.Name)) { $satisfied = $true; break }
                }
                if ($satisfied) { break }
            }
            if (-not $satisfied) { continue }
        }

        return $rule
    }
    return $null
}

function Invoke-CleanDirectoryWalk {
    [CmdletBinding()]
    param(
        [string]$Current,
        [AllowEmptyCollection()][string[]]$RelSegments,
        $Config
    )

    if ($RelSegments.Count -gt 0) {
        if (Test-CleanAnyRuleMatch -Rules $Config.Exclude -Segments $RelSegments) {
            return
        }

        $matchedRule = Find-CleanDirectoryMatch -Rules $Config.Directories -Segments $RelSegments -Current $Current
        if ($matchedRule) {
            [pscustomobject]@{
                PSTypeName = 'ProjectClean.Item'
                Path       = $Current
                Kind       = 'Directory'
                Rule       = $matchedRule.Pattern
                Size       = $null
                FileCount  = $null
                Action     = 'Pending'
            }
            return
        }
    }

    try {
        $entries = Get-ChildItem -LiteralPath $Current -Force -ErrorAction Stop
    }
    catch {
        Write-Warning "Cannot read directory '$Current': $_"
        return
    }

    foreach ($entry in $entries) {
        $childSegs = @($RelSegments) + $entry.Name

        if ($entry.PSIsContainer) {
            $isReparse = ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0

            if ($isReparse) {
                if (Test-CleanAnyRuleMatch -Rules $Config.Exclude -Segments $childSegs) {
                    continue
                }
                $rule = Find-CleanDirectoryMatch -Rules $Config.Directories -Segments $childSegs -Current $entry.FullName
                if ($rule) {
                    [pscustomobject]@{
                        PSTypeName = 'ProjectClean.Item'
                        Path       = $entry.FullName
                        Kind       = 'Directory'
                        Rule       = $rule.Pattern
                        Size       = $null
                        FileCount  = $null
                        Action     = 'Pending'
                    }
                }
                continue
            }

            Invoke-CleanDirectoryWalk -Current $entry.FullName -RelSegments $childSegs -Config $Config
        }
        else {
            if (Test-CleanAnyRuleMatch -Rules $Config.Exclude -Segments $childSegs) {
                continue
            }
            foreach ($fr in $Config.Files) {
                if ([WildcardPattern]::Get($fr.Pattern, 'IgnoreCase').IsMatch($entry.Name)) {
                    [pscustomobject]@{
                        PSTypeName = 'ProjectClean.Item'
                        Path       = $entry.FullName
                        Kind       = 'File'
                        Rule       = $fr.Pattern
                        Size       = $entry.Length
                        FileCount  = 1
                        Action     = 'Pending'
                    }
                    break
                }
            }
        }
    }
}

function Get-CleanMatch {
    <#
    .SYNOPSIS
    Walks a directory tree and yields candidates for cleaning.

    .DESCRIPTION
    Emits ProjectClean.Item objects describing directories and files that match
    the configured rules. Matched directories are pruned from the walk so the
    walker does not enumerate inside them.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Config
    )

    $rootFull = [IO.Path]::GetFullPath($Path)
    Invoke-CleanDirectoryWalk -Current $rootFull -RelSegments @() -Config $Config
}
