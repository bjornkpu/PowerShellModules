function Deploy-PythonPackage {
    <#
    .SYNOPSIS
    Bumps version, builds, and deploys a Python package to Databricks.

    .DESCRIPTION
    This function automates the Python package deployment workflow:
    1. Bumps the version in pyproject.toml (patch/minor/major)
    2. Runs poetry build in a virtual environment
    3. Uploads and installs the package to Databricks cluster

    .PARAMETER BumpType
    The type of version bump: 'major', 'minor', or 'patch' (default: patch)

    .EXAMPLE
    Deploy-PythonPackage
    Bumps the patch version and deploys

    .EXAMPLE
    Deploy-PythonPackage -BumpType minor
    Bumps the minor version and deploys
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('major', 'minor', 'patch')]
        [string]$BumpType = 'patch'
    )

    # Load config
    $config = Get-ModuleConfig -ModuleName 'Databricks' `
        -SchemaPath "$PSScriptRoot/../config.schema.json" `
        -ExampleConfigPath "$PSScriptRoot/../config.example.json"

    $dbConfig = $config.databricks

    # Project directory
    $projectPath = Join-Path $dbConfig.workspacePath $dbConfig.defaultPackage
    $pyprojectPath = Join-Path $projectPath "pyproject.toml"

    # Check if project directory exists
    if (-not (Test-Path $projectPath)) {
        throw "Project directory not found at $projectPath"
    }

    # Check if pyproject.toml exists
    if (-not (Test-Path $pyprojectPath)) {
        throw "pyproject.toml not found at $pyprojectPath"
    }

    # Read the pyproject.toml file
    $content = Get-Content $pyprojectPath -Raw

    # Extract current version using regex
    if ($content -match 'version\s*=\s*"(\d+)\.(\d+)\.(\d+)"') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3]
        $currentVersion = "$major.$minor.$patch"

        Write-Host "Current version: $currentVersion" -ForegroundColor Yellow

        # Bump version based on type
        switch ($BumpType) {
            'major' {
                $major++
                $minor = 0
                $patch = 0
            }
            'minor' {
                $minor++
                $patch = 0
            }
            'patch' {
                $patch++
            }
        }

        $newVersion = "$major.$minor.$patch"
        Write-Host "New version:     $newVersion" -ForegroundColor Green

        # Update the version in pyproject.toml
        $newContent = $content -replace 'version\s*=\s*"\d+\.\d+\.\d+"', "version = `"$newVersion`""
        Set-Content -Path $pyprojectPath -Value $newContent -NoNewline
    }
    else {
        throw "Could not find version in pyproject.toml"
    }

    # Change to project directory for poetry build
    Push-Location $projectPath

    try {
        # Activate Python environment
        $venvActivate = Join-Path $projectPath ".venv\Scripts\Activate.ps1"
        if (Test-Path $venvActivate) {
            . $venvActivate
        }
        else {
            Write-Warning "Virtual environment not found at .venv. Attempting build without activation..."
        }

        # Run poetry build
        Write-Host "`nBuilding package..." -ForegroundColor Cyan
        poetry build

        if ($LASTEXITCODE -ne 0) {
            throw "Poetry build failed!"
        }

        # Deactivate virtual environment before deployment
        if (Get-Command deactivate -ErrorAction SilentlyContinue) {
            deactivate
        }

        # Run deployment command
        Write-Host "`nDeploying to Databricks..." -ForegroundColor Cyan
        Invoke-DatabricksCommand -Command upstall -PackageVersion $newVersion

        if ($LASTEXITCODE -ne 0) {
            throw "Deployment failed!"
        }

        Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
        Write-Host "Version $newVersion has been deployed." -ForegroundColor Green
    }
    finally {
        # Return to original directory
        Pop-Location
    }
}
