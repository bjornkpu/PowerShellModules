function Resolve-TestPath {
    <#
    .SYNOPSIS
    Resolve test pattern to test file/directory and corresponding source path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    $testsDir = "tests"
    $srcDir = "src\$ProjectName"

    # Validate tests directory exists
    if (-not (Test-Path $testsDir)) {
        throw "No tests/ directory found in current directory"
    }

    # No pattern = watch everything
    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        Write-Verbose "No pattern specified, watching all tests"
        return @{
            TestPath    = $testsDir
            SourcePath  = $srcDir
            IsDirectory = $true
        }
    }

    # Directory mode (trailing slash)
    if ($Pattern.EndsWith('/') -or $Pattern.EndsWith('\')) {
        $dirPattern = $Pattern.TrimEnd('/', '\')
        
        # First try direct path
        $testPath = Join-Path $testsDir $dirPattern
        
        # If not found, search recursively for directory by name
        if (-not (Test-Path $testPath)) {
            Write-Verbose "Directory not found at $testPath, searching recursively..."
            $foundDirs = Get-ChildItem -Path $testsDir -Directory -Recurse -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -eq $dirPattern }
            
            if (-not $foundDirs) {
                throw "Directory not found: $dirPattern (searched in $testsDir)"
            }
            
            if ($foundDirs.Count -gt 1) {
                Write-Warning "Multiple directories found matching '$dirPattern':"
                $foundDirs | ForEach-Object { Write-Warning "  $($_.FullName)" }
                throw "Ambiguous directory name. Please use full path (e.g., 'parent/$dirPattern/')"
            }
            
            $testPath = $foundDirs[0].FullName
        }
        
        # Derive source path from test path - preserve full structure
        $relativePath = $testPath -replace [regex]::Escape((Get-Location).Path + '\'), ''
        $relativePath = $relativePath -replace [regex]::Escape($testsDir + '\'), ''
        $relativePath = $relativePath -replace '\\', '/'
        
        # Preserve full path structure in source
        $sourcePath = Join-Path $srcDir $relativePath

        Write-Verbose "Directory mode: $testPath"
        Write-Verbose "Source path: $sourcePath"
        return @{
            TestPath    = $testPath
            SourcePath  = $sourcePath
            IsDirectory = $true
        }
    }

    # File mode with directory qualification (e.g., "stotteregisteret/key_vault")
    if ($Pattern -match '[/\\]') {
        $parts = $Pattern -split '[/\\]'
        $dirPart = $parts[0]  # Immediate directory name
        $filePart = $parts[-1]

        # Search for directory by name
        $foundDirs = Get-ChildItem -Path $testsDir -Directory -Recurse -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -eq $dirPart }
        
        if (-not $foundDirs) {
            throw "Directory not found: $dirPart (searched in $testsDir)"
        }
        
        if ($foundDirs.Count -gt 1) {
            Write-Warning "Multiple directories found matching '$dirPart':"
            $foundDirs | ForEach-Object { Write-Warning "  $($_.FullName)" }
            throw "Ambiguous directory name. Please be more specific."
        }
        
        $searchDir = $foundDirs[0].FullName
        $filePattern = "test_*$filePart*_unit.py"

        Write-Verbose "Searching for $filePattern in $searchDir"
        $matches = Get-ChildItem -Path $searchDir -Filter $filePattern -File -ErrorAction SilentlyContinue
    }
    else {
        # Simple file mode - search recursively for _unit.py files only
        $filePattern = "test_*$Pattern*_unit.py"
        Write-Verbose "Searching for $filePattern in $testsDir (recursive)"
        $matches = Get-ChildItem -Path $testsDir -Filter $filePattern -File -Recurse -ErrorAction SilentlyContinue
    }

    if (-not $matches) {
        throw "No test file found matching: $Pattern"
    }

    if ($matches.Count -gt 1) {
        Write-Warning "Multiple test files found matching '$Pattern':"
        $matches | ForEach-Object { Write-Warning "  $($_.FullName)" }
        throw "Ambiguous pattern. Please be more specific or use directory mode (e.g., 'dirname/')"
    }

    $testFile = $matches[0]
    $relativeDir = Split-Path $testFile.FullName -Parent
    $relativeDir = $relativeDir -replace [regex]::Escape((Get-Location).Path + '\'), ''
    $relativeDir = $relativeDir -replace [regex]::Escape($testsDir + '\'), ''

    $sourcePath = if ($relativeDir) {
        Join-Path $srcDir $relativeDir
    }
    else {
        $srcDir
    }

    Write-Verbose "Resolved test file: $($testFile.FullName)"
    Write-Verbose "Corresponding source: $sourcePath"

    return @{
        TestPath    = $testFile.FullName
        SourcePath  = $sourcePath
        IsDirectory = $false
    }
}
