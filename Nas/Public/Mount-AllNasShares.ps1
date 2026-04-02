function Mount-AllNasShares {
    [CmdletBinding()]
    param()

    if (-not $script:NasConfig) {
        $script:NasConfig = Get-ModuleConfig -ModuleName 'Nas'
    }

    if (-not $script:NasConfig.shares) {
        Write-Error "No shares defined in Nas config. Add a 'shares' array to ~/.config/Nas/config.json"
        return
    }

    foreach ($share in $script:NasConfig.shares) {
        Mount-NasShare -ShareName $share.name -DriveLetter $share.driveLetter
    }
}
