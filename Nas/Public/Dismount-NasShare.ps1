function Dismount-NasShare {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByShareName')]
        [string]$ShareName,

        [Parameter(Mandatory, ParameterSetName = 'ByDriveLetter')]
        [ValidatePattern('^[A-Z]$')]
        [string]$DriveLetter
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByShareName') {
        if (-not $script:NasConfig) {
            $script:NasConfig = Get-ModuleConfig -ModuleName 'Nas'
        }

        $uncPath = "\\$($script:NasConfig.hostname)\$ShareName"
        $mapping = Get-SmbMapping -ErrorAction SilentlyContinue | Where-Object { $_.RemotePath -eq $uncPath }

        if (-not $mapping) {
            Write-Error "No SMB mapping found for $uncPath"
            return
        }

        $localPath = $mapping.LocalPath
    }
    else {
        $localPath = "$($DriveLetter):"
    }

    Write-Host "Unmounting $localPath"
    net use $localPath /delete | Out-Null
    Write-Host "Unmounted $localPath"
}
