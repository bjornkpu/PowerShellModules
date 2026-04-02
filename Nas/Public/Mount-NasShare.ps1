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

    $hostname = $script:NasConfig.hostname
    $uncPath = "\\$hostname\$ShareName"

    # Store credentials in Windows Credential Manager for reboot persistence
    cmdkey /add:$hostname /user:$($script:NasConfig.username) /pass:$($script:NasConfig.password) | Out-Null

    # Clean up stale connections to this server
    $existing = Get-SmbMapping -ErrorAction SilentlyContinue | Where-Object { $_.RemotePath -like "\\$hostname\*" }
    foreach ($mapping in $existing) {
        if (-not (Test-Path $mapping.LocalPath)) {
            Write-Host "Removing stale mapping $($mapping.LocalPath) -> $($mapping.RemotePath)"
            net use $mapping.LocalPath /delete /y 2>$null | Out-Null
        }
    }

    if (-not $DriveLetter) {
        $used = (Get-SmbMapping -ErrorAction SilentlyContinue).LocalPath -replace ':$' | Where-Object { $_ }
        $DriveLetter = ([char[]]('D'..'Z') | Where-Object { $_ -notin $used -and -not (Test-Path "$($_):") } | Select-Object -First 1)
        if (-not $DriveLetter) {
            Write-Error "No free drive letters available"
            return
        }
    }

    $localPath = "$($DriveLetter):"

    # Skip if already correctly mapped and accessible
    $current = Get-SmbMapping -LocalPath $localPath -ErrorAction SilentlyContinue
    if ($current -and $current.RemotePath -eq $uncPath -and (Test-Path $localPath)) {
        Write-Host "$uncPath already mounted on $localPath"
        return
    }

    if ($current) {
        Write-Error "Drive $localPath already mapped to $($current.RemotePath)"
        return
    }

    Write-Host "Mounting $uncPath -> $localPath"
    net use $localPath $uncPath /user:$($script:NasConfig.username) $($script:NasConfig.password) /persistent:yes | Out-Null
    Write-Host "Mounted $uncPath on $localPath"
}
