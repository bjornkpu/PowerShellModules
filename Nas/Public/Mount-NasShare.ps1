function Mount-NasShare {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ShareName,

        [Parameter()]
        [ValidatePattern('^[A-Z]$')]
        [string]$DriveLetter
    )

    if (-not $script:NasConfig) {
        $script:NasConfig = Get-ModuleConfig -ModuleName 'Nas'
    }

    $uncPath = "\\$($script:NasConfig.hostname)\$ShareName"

    if (-not $DriveLetter) {
        $used = (Get-SmbMapping -ErrorAction SilentlyContinue).LocalPath -replace ':$' | Where-Object { $_ }
        $DriveLetter = ([char[]]('D'..'Z') | Where-Object { $_ -notin $used -and -not (Test-Path "$($_):") } | Select-Object -First 1)
        if (-not $DriveLetter) {
            Write-Error "No free drive letters available"
            return
        }
    }

    $localPath = "$($DriveLetter):"

    $existing = Get-SmbMapping -LocalPath $localPath -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Error "Drive $localPath already mapped to $($existing.RemotePath)"
        return
    }

    Write-Host "Mounting $uncPath -> $localPath"
    net use $localPath $uncPath /user:$($script:NasConfig.username) $($script:NasConfig.password) /persistent:yes | Out-Null
    Write-Host "Mounted $uncPath on $localPath"
}
