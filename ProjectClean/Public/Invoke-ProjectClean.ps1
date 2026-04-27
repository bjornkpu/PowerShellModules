function Invoke-ProjectClean {
    <#
    .SYNOPSIS
    Walks a directory tree and removes configured build artifacts and dependency caches.

    .DESCRIPTION
    Loads the user's ProjectClean configuration from ~/.config/ProjectClean/config.json,
    walks the target directory, and removes everything that matches a directories or files
    rule. Excluded paths are never touched. Matched directories are pruned from the walk
    (one delete per node_modules, not 200k).

    By default the cmdlet prints a summary of what would be removed and asks once for
    confirmation before deleting anything. -WhatIf shows the plan without deleting.

    .PARAMETER Path
    Root directory to clean. Defaults to current location.

    .PARAMETER IncludeSize
    Compute size and file count for each candidate. Adds one recursive enumeration per
    matched directory, so it is opt-in.

    .PARAMETER Quiet
    Suppress per-item verbose output. Summary line still prints.

    .PARAMETER PassThru
    Emit one ProjectClean.Item object per processed candidate.

    .PARAMETER Acknowledge
    Required when the active config does not exclude .git. Forces the user to acknowledge
    that they are deliberately allowing the cleaner to consider .git directories.

    .EXAMPLE
    Invoke-ProjectClean -Path C:\repos\myproject

    .EXAMPLE
    Invoke-ProjectClean -Path . -WhatIf -Verbose

    .EXAMPLE
    Invoke-ProjectClean -Path C:\repos\myproject -IncludeSize -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [string]$Path = (Get-Location).Path,

        [switch]$IncludeSize,
        [switch]$Quiet,
        [switch]$PassThru,
        [switch]$Acknowledge
    )

    $config = Get-CleanConfig

    if (-not $config.HasGitExclude -and -not $Acknowledge) {
        throw "Refusing to run: '.git' is not in the exclude list. Re-run with -Acknowledge to override."
    }
    if (-not $config.HasGitExclude) {
        Write-Warning "'.git' is not in the exclude list. Proceeding because -Acknowledge was passed."
    }

    Test-PathSafety -Path $Path -ExtraForbidden $config.ForbiddenRoots

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $candidates = @(Get-CleanMatch -Path $Path -Config $config)

    if ($candidates.Count -eq 0) {
        Write-Host "Nothing to clean."
        return
    }

    if ($IncludeSize) {
        foreach ($c in $candidates) {
            $info = Get-CleanItemSize -Item $c
            $c.Size = $info.Size
            $c.FileCount = $info.FileCount
        }
    }

    $dirCount = ($candidates | Where-Object Kind -EQ 'Directory').Count
    $fileCount = ($candidates | Where-Object Kind -EQ 'File').Count
    $totalBytes = ($candidates | Measure-Object -Property Size -Sum).Sum

    $sizeText = if ($IncludeSize) { ", $([math]::Round($totalBytes / 1MB, 2)) MB" } else { '' }
    $summary = "Found $dirCount directories and $fileCount files to remove$sizeText."
    Write-Host $summary

    $target = (Resolve-Path -LiteralPath $Path).Path
    if (-not $PSCmdlet.ShouldProcess($target, "Remove $dirCount directories and $fileCount files")) {
        if ($PassThru) {
            foreach ($c in $candidates) { $c.Action = 'WouldRemove' }
            $candidates
        }
        return
    }

    $failures = 0
    foreach ($c in $candidates) {
        $ok = Remove-CleanItem -Item $c
        if ($ok) {
            $c.Action = 'Removed'
            if (-not $Quiet) {
                Write-Verbose "Removed: $($c.Path)"
            }
        }
        else {
            $c.Action = 'Failed'
            $failures++
        }
    }

    $stopwatch.Stop()
    $removed = $candidates.Count - $failures
    Write-Host "Removed $removed of $($candidates.Count) item(s) in $([math]::Round($stopwatch.Elapsed.TotalSeconds, 2))s."

    if ($PassThru) {
        $candidates
    }

    if ($failures -gt 0) {
        throw "$failures item(s) could not be removed."
    }
}
