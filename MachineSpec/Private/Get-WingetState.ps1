function Get-WingetState {
    [CmdletBinding()]
    param(
        [switch]$IncludeStoreApps
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found on PATH."
    }

    $temp = New-TemporaryFile
    try {
        $tempJson = [System.IO.Path]::ChangeExtension($temp.FullName, '.json')
        Move-Item -LiteralPath $temp.FullName -Destination $tempJson -Force | Out-Null

        $cmdArgs = @('export', '-o', $tempJson, '--include-versions', '--accept-source-agreements')
        if (-not $IncludeStoreApps) { $cmdArgs += @('--source', 'winget') }

        $proc = Start-Process -FilePath 'winget' -ArgumentList $cmdArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$tempJson.out" -RedirectStandardError "$tempJson.err"
        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne -1978335189) {
            $err = if (Test-Path "$tempJson.err") { Get-Content "$tempJson.err" -Raw } else { '' }
            throw "winget export failed (exit $($proc.ExitCode)): $err"
        }

        if (-not (Test-Path -LiteralPath $tempJson)) {
            return @()
        }
        $data = Get-Content -LiteralPath $tempJson -Raw | ConvertFrom-Json -Depth 10

        $packages = @()
        foreach ($source in @($data.Sources)) {
            $sourceName = $source.SourceDetails.Name
            if (-not $IncludeStoreApps -and $sourceName -eq 'msstore') { continue }
            foreach ($pkg in @($source.Packages)) {
                $packages += [pscustomobject]@{
                    Id      = [string]$pkg.PackageIdentifier
                    Version = if ($pkg.Version) { [string]$pkg.Version } else { $null }
                    Source  = $sourceName
                }
            }
        }
        ,$packages
    }
    finally {
        foreach ($f in @($tempJson, "$tempJson.out", "$tempJson.err")) {
            if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
        }
    }
}
