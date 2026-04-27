function Get-DotNetToolState {
    [CmdletBinding()]
    param()

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw "'dotnet' not found on PATH."
    }

    $raw = & dotnet tool list -g --format json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "'dotnet tool list -g' failed: $($raw -join "`n")"
    }

    $data = ($raw -join "`n") | ConvertFrom-Json
    $tools = @()
    foreach ($t in @($data.data)) {
        $tools += [pscustomobject]@{
            Id      = [string]$t.packageId
            Version = [string]$t.version
        }
    }
    ,$tools
}
