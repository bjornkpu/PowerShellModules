function Remove-CleanItem {
    <#
    .SYNOPSIS
    Deletes a single ProjectClean.Item, treating reparse points as links.

    .DESCRIPTION
    Returns $true on success, $false on failure. Does not throw.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Item
    )

    try {
        $info = Get-Item -LiteralPath $Item.Path -Force -ErrorAction Stop
        $isReparse = ($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0

        if ($Item.Kind -eq 'Directory') {
            if ($isReparse) {
                [IO.Directory]::Delete($Item.Path, $false)
            }
            else {
                Remove-Item -LiteralPath $Item.Path -Recurse -Force -ErrorAction Stop
            }
        }
        else {
            if ($isReparse) {
                [IO.File]::Delete($Item.Path)
            }
            else {
                Remove-Item -LiteralPath $Item.Path -Force -ErrorAction Stop
            }
        }
        return $true
    }
    catch {
        Write-Warning "Failed to remove '$($Item.Path)': $_"
        return $false
    }
}

function Get-CleanItemSize {
    <#
    .SYNOPSIS
    Computes total bytes and file count under a ProjectClean.Item.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Item
    )

    if ($Item.Kind -eq 'File') {
        return [pscustomobject]@{ Size = $Item.Size; FileCount = 1 }
    }

    $bytes = 0L
    $count = 0
    try {
        $files = Get-ChildItem -LiteralPath $Item.Path -Recurse -File -Force -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $bytes += $f.Length
            $count++
        }
    }
    catch {
        Write-Verbose "Could not enumerate '$($Item.Path)' for size: $_"
    }
    return [pscustomobject]@{ Size = $bytes; FileCount = $count }
}
