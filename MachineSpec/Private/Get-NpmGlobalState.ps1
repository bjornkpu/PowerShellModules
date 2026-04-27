function Get-NpmGlobalState {
    [CmdletBinding()]
    param()

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "'npm' not found on PATH."
    }

    $raw = & npm ls -g --json --depth=0 2>$null
    if (-not $raw) { return ,@() }

    $data = ($raw -join "`n") | ConvertFrom-Json
    $globals = @()
    if ($data.dependencies) {
        foreach ($prop in $data.dependencies.PSObject.Properties) {
            $globals += [pscustomobject]@{
                Name    = $prop.Name
                Version = [string]$prop.Value.version
            }
        }
    }
    ,$globals
}
