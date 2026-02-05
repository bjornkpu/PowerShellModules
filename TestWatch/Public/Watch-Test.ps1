function Watch-Test {
    <#
    .SYNOPSIS
    Watch tests with fuzzy search and automatic source path derivation

    .DESCRIPTION
    Intelligent wrapper for pytest-watch that auto-detects Poetry/UV, searches for test files with fuzzy matching,
    and derives source directories from test paths.

    .PARAMETER TestPattern
    Optional test file or directory pattern. Supports:
    - Empty: Watch all tests
    - 'key_vault': Fuzzy search for test_*key_vault*.py
    - 'connectors/': Watch entire connectors directory
    - 'connectors/key_vault': Fuzzy search in specific directory

    .EXAMPLE
    tw
    Watch all tests in tests/ directory

    .EXAMPLE
    tw key_vault
    Fuzzy search for test file matching 'key_vault'

    .EXAMPLE
    tw connectors/
    Watch all tests in tests/connectors/ directory

    .EXAMPLE
    tw connectors/key_vault
    Search for test file in connectors directory matching 'key_vault'
    #>
    [CmdletBinding()]
    [Alias('tw')]
    param(
        [Parameter(Position = 0)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

                # Scan for test files in tests/ directory
                $testsDir = Join-Path (Get-Location) "tests"
                if (-not (Test-Path $testsDir)) {
                    return @()
                }

                # Get all _unit.py test files
                $testFiles = Get-ChildItem -Path $testsDir -Filter "test_*_unit.py" -Recurse -File

                $candidates = @()
                $directories = @{}

                foreach ($file in $testFiles) {
                    $relativePath = $file.FullName -replace [regex]::Escape($testsDir + [IO.Path]::DirectorySeparatorChar), ''
                    $relativePath = $relativePath -replace '\\', '/'

                    # Strip test_ prefix and .py extension
                    $name = $file.Name -replace '^test_', '' -replace '\.py$', ''

                    # Get full parent path and extract immediate parent directory only
                    $fullParentPath = Split-Path $relativePath -Parent
                    
                    if ($fullParentPath) {
                        # Ensure forward slashes
                        $fullParentPath = $fullParentPath -replace '\\', '/'
                        
                        # Get immediate parent directory (last component)
                        $immediateParent = ($fullParentPath -split '/')[-1]
                        
                        # Add directory as a completion option (with trailing slash)
                        $directories[$immediateParent] = $true
                        
                        # Add file with immediate parent only
                        $candidates += "$immediateParent/$name"
                    }
                    else {
                        $candidates += $name
                    }
                }

                # Add directories as completions (with trailing slash)
                foreach ($dir in $directories.Keys) {
                    $candidates += "$dir/"
                }

                # Filter by word to complete and return unique sorted results
                $candidates | Where-Object { $_ -like "*$wordToComplete*" } | Sort-Object -Unique
            })]
        [string]$TestPattern = ""
    )

    # Auto-detect test runner
    $runnerPrefix = Get-TestRunner

    # Get project name for source path derivation
    $projectName = Get-ProjectName

    # Resolve test pattern to paths
    try {
        $resolved = Resolve-TestPath -Pattern $TestPattern -ProjectName $projectName
    }
    catch {
        Write-Error $_
        return
    }

    # Build pytest-watch command
    # Format: poetry/uv run pytest-watch <test_path> <source_path>
    $command = "$runnerPrefix-watch"
    
    # Convert absolute paths to relative paths with forward slashes
    $currentDir = (Get-Location).Path -replace '\\', '/'
    $testPathRelative = $resolved.TestPath -replace '\\', '/' -replace [regex]::Escape($currentDir + '/'), ''
    $sourcePathRelative = $resolved.SourcePath -replace '\\', '/' -replace [regex]::Escape($currentDir + '/'), ''
    
    $args = @($testPathRelative)

    # Add source path if it exists
    if (Test-Path $resolved.SourcePath) {
        $args += $sourcePathRelative
    }

    Write-Verbose "Running: $command $($args -join ' ')"

    # Execute pytest-watch (it handles all the watching)
    # Build full command with proper argument passing
    $fullCommand = "$command $testPathRelative"
    if (Test-Path $resolved.SourcePath) {
        $fullCommand += " $sourcePathRelative"
    }
    
    Invoke-Expression $fullCommand
}