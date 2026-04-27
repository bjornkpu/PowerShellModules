function Get-UvToolState {
    [CmdletBinding()]
    param()

    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        throw "'uv' not found on PATH."
    }

    $raw = & uv tool list 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "'uv tool list' failed: $($raw -join "`n")"
    }

    $tools = @()
    foreach ($line in @($raw)) {
        $text = [string]$line
        if ($text -match '^(\S[^\s]*)\s+v(\S+)\s*$') {
            $tools += [pscustomobject]@{
                Name    = $matches[1]
                Version = $matches[2]
            }
        }
    }
    ,$tools
}
