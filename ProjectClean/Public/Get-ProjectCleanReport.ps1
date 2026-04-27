function Get-ProjectCleanReport {
    <#
    .SYNOPSIS
    Reports what Invoke-ProjectClean would remove from a directory tree, without deleting.

    .DESCRIPTION
    Same walk as Invoke-ProjectClean but read-only. Prints a table of matches and a
    totals line. Useful for figuring out which projects are bloated before deciding
    to clean them.

    .PARAMETER Path
    Root directory to inspect. Defaults to current location.

    .PARAMETER IncludeSize
    Compute size and file count for each match. Slower but populates the totals.

    .PARAMETER PassThru
    Emit one ProjectClean.Item object per match. Suppresses the formatted table.

    .EXAMPLE
    Get-ProjectCleanReport -Path C:\repos -IncludeSize

    .EXAMPLE
    Get-ProjectCleanReport -Path . -PassThru | Where-Object Size -gt 100MB
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path = (Get-Location).Path,

        [switch]$IncludeSize,
        [switch]$PassThru
    )

    $config = Get-CleanConfig
    Test-PathSafety -Path $Path -ExtraForbidden $config.ForbiddenRoots

    $candidates = @(Get-CleanMatch -Path $Path -Config $config)
    foreach ($c in $candidates) { $c.Action = 'WouldRemove' }

    if ($IncludeSize) {
        foreach ($c in $candidates) {
            $info = Get-CleanItemSize -Item $c
            $c.Size = $info.Size
            $c.FileCount = $info.FileCount
        }
    }

    if ($PassThru) {
        return $candidates
    }

    if ($candidates.Count -eq 0) {
        Write-Host "Nothing matched."
        return
    }

    $candidates | Format-Table -Property Path, Kind, Rule, Size, FileCount -AutoSize | Out-Host

    $dirCount = ($candidates | Where-Object Kind -EQ 'Directory').Count
    $fileCount = ($candidates | Where-Object Kind -EQ 'File').Count
    $totalBytes = ($candidates | Measure-Object -Property Size -Sum).Sum
    $sizeText = if ($IncludeSize) { ", $([math]::Round($totalBytes / 1MB, 2)) MB" } else { '' }
    Write-Host "Total: $dirCount directories, $fileCount files$sizeText."
}
