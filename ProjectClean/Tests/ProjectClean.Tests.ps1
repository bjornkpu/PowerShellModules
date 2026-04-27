BeforeAll {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $repoRoot = Split-Path -Parent $moduleRoot

    Import-Module (Join-Path $repoRoot 'Shared') -Force -DisableNameChecking
    Import-Module $moduleRoot -Force -DisableNameChecking
}

Describe 'ProjectClean' {

    BeforeEach {
        $script:testRoot = Join-Path ([IO.Path]::GetTempPath()) ("pc-test-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null

        # .git should be left alone
        New-Item -ItemType Directory -Path "$testRoot/.git" -Force | Out-Null
        Set-Content -LiteralPath "$testRoot/.git/HEAD" -Value 'ref: refs/heads/main'

        # .NET project — bin/obj guarded by .csproj sibling
        Set-Content -LiteralPath "$testRoot/app.csproj" -Value '<Project></Project>'
        New-Item -ItemType Directory -Path "$testRoot/bin/Debug" -Force | Out-Null
        Set-Content -LiteralPath "$testRoot/bin/Debug/foo.dll" -Value 'binary'
        New-Item -ItemType Directory -Path "$testRoot/obj/Debug" -Force | Out-Null
        Set-Content -LiteralPath "$testRoot/obj/Debug/foo.cache" -Value 'cache'

        # tools/bin — NOT a .NET bin (no .csproj sibling), should be left alone
        New-Item -ItemType Directory -Path "$testRoot/tools/bin" -Force | Out-Null
        Set-Content -LiteralPath "$testRoot/tools/bin/script.sh" -Value '#!/bin/sh'

        # Node project
        New-Item -ItemType Directory -Path "$testRoot/frontend/node_modules/lodash" -Force | Out-Null
        Set-Content -LiteralPath "$testRoot/frontend/package.json" -Value '{}'
        Set-Content -LiteralPath "$testRoot/frontend/node_modules/lodash/index.js" -Value 'module.exports={}'

        # Python project — venv + __pycache__ + .pyc files
        New-Item -ItemType Directory -Path "$testRoot/api/.venv/Lib" -Force | Out-Null
        Set-Content -LiteralPath "$testRoot/api/pyproject.toml" -Value '[project]'
        New-Item -ItemType Directory -Path "$testRoot/api/__pycache__" -Force | Out-Null
        Set-Content -LiteralPath "$testRoot/api/__pycache__/x.pyc" -Value 'pyc'
        Set-Content -LiteralPath "$testRoot/api/main.pyc" -Value 'top-level pyc'

        # Rust project — target/ guarded by Cargo.toml
        New-Item -ItemType Directory -Path "$testRoot/rust-app/target/debug" -Force | Out-Null
        Set-Content -LiteralPath "$testRoot/rust-app/Cargo.toml" -Value '[package]'
        Set-Content -LiteralPath "$testRoot/rust-app/target/debug/app.exe" -Value 'compiled'

        # Excluded subtree
        New-Item -ItemType Directory -Path "$testRoot/vendored/dep/build" -Force | Out-Null
        Set-Content -LiteralPath "$testRoot/vendored/dep/build/lib.so" -Value 'leave-alone'

        # Test config — same defaults as config.example.json
        $cfgJson = @'
{
    "directories": [
        "node_modules", ".venv", "__pycache__", "build",
        { "name": "bin",    "requires": ["*.csproj", "*.sln"] },
        { "name": "obj",    "requires": ["*.csproj", "*.sln"] },
        { "name": "target", "requires": ["Cargo.toml", "pom.xml"] }
    ],
    "files": ["*.pyc"],
    "exclude": [".git", "vendored/**"]
}
'@
        $script:testConfig = $cfgJson | ConvertFrom-Json

        Mock -ModuleName ProjectClean Get-ModuleConfig { $script:testConfig }
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:testRoot) {
            Remove-Item -LiteralPath $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Walker (via Get-ProjectCleanReport -PassThru)' {

        It 'yields the expected directories and files' {
            $report = Get-ProjectCleanReport -Path $testRoot -PassThru

            $dirs = $report | Where-Object Kind -EQ 'Directory' | ForEach-Object { $_.Path }
            $files = $report | Where-Object Kind -EQ 'File' | ForEach-Object { $_.Path }

            $dirs | Should -Contain (Join-Path $testRoot 'frontend/node_modules')
            $dirs | Should -Contain (Join-Path $testRoot 'api/.venv')
            $dirs | Should -Contain (Join-Path $testRoot 'api/__pycache__')
            $dirs | Should -Contain (Join-Path $testRoot 'bin')
            $dirs | Should -Contain (Join-Path $testRoot 'obj')
            $dirs | Should -Contain (Join-Path $testRoot 'rust-app/target')

            $files | Should -Contain (Join-Path $testRoot 'api/main.pyc')
        }

        It 'leaves tools/bin alone (no .csproj sibling — guarded rule)' {
            $report = Get-ProjectCleanReport -Path $testRoot -PassThru
            $dirs = $report | Where-Object Kind -EQ 'Directory' | ForEach-Object { $_.Path }
            $dirs | Should -Not -Contain (Join-Path $testRoot 'tools/bin')
        }

        It 'does not yield items inside matched directories (pruning)' {
            $report = Get-ProjectCleanReport -Path $testRoot -PassThru
            $paths = $report | ForEach-Object { $_.Path }
            $paths | Should -Not -Contain (Join-Path $testRoot 'frontend/node_modules/lodash')
            $paths | Should -Not -Contain (Join-Path $testRoot 'frontend/node_modules/lodash/index.js')
        }

        It 'respects exclude (vendored/** is skipped)' {
            $report = Get-ProjectCleanReport -Path $testRoot -PassThru
            $paths = $report | ForEach-Object { $_.Path }
            $paths | Should -Not -Contain (Join-Path $testRoot 'vendored/dep/build')
        }

        It 'does not match .pyc files inside excluded subtrees' {
            Set-Content -LiteralPath "$testRoot/vendored/dep/build/cached.pyc" -Value 'should-not-match'
            $report = Get-ProjectCleanReport -Path $testRoot -PassThru
            $paths = $report | ForEach-Object { $_.Path }
            $paths | Should -Not -Contain (Join-Path $testRoot 'vendored/dep/build/cached.pyc')
        }

        It 'does not yield .git contents' {
            $report = Get-ProjectCleanReport -Path $testRoot -PassThru
            $paths = $report | ForEach-Object { $_.Path }
            $paths | Where-Object { $_ -like "*\.git\*" } | Should -BeNullOrEmpty
        }
    }

    Context 'IncludeSize' {
        It 'populates Size and FileCount when -IncludeSize is set' {
            $report = Get-ProjectCleanReport -Path $testRoot -PassThru -IncludeSize
            $dir = $report | Where-Object { $_.Path -eq (Join-Path $testRoot 'frontend/node_modules') } | Select-Object -First 1
            $dir | Should -Not -BeNullOrEmpty
            $dir.Size | Should -BeGreaterThan 0
            $dir.FileCount | Should -BeGreaterThan 0
        }

        It 'leaves Size null when -IncludeSize is omitted (for directories)' {
            $report = Get-ProjectCleanReport -Path $testRoot -PassThru
            $dir = $report | Where-Object { $_.Path -eq (Join-Path $testRoot 'frontend/node_modules') } | Select-Object -First 1
            $dir.Size | Should -BeNullOrEmpty
        }
    }

    Context 'Invoke-ProjectClean' {
        It '-WhatIf does not delete anything' {
            Invoke-ProjectClean -Path $testRoot -WhatIf -Confirm:$false 6>$null
            (Test-Path -LiteralPath "$testRoot/frontend/node_modules") | Should -BeTrue
            (Test-Path -LiteralPath "$testRoot/api/.venv") | Should -BeTrue
            (Test-Path -LiteralPath "$testRoot/api/main.pyc") | Should -BeTrue
        }

        It 'removes matched items and is idempotent' {
            Invoke-ProjectClean -Path $testRoot -Confirm:$false 6>$null

            (Test-Path -LiteralPath "$testRoot/frontend/node_modules") | Should -BeFalse
            (Test-Path -LiteralPath "$testRoot/api/.venv") | Should -BeFalse
            (Test-Path -LiteralPath "$testRoot/api/__pycache__") | Should -BeFalse
            (Test-Path -LiteralPath "$testRoot/bin") | Should -BeFalse
            (Test-Path -LiteralPath "$testRoot/obj") | Should -BeFalse
            (Test-Path -LiteralPath "$testRoot/rust-app/target") | Should -BeFalse
            (Test-Path -LiteralPath "$testRoot/api/main.pyc") | Should -BeFalse

            # untouched
            (Test-Path -LiteralPath "$testRoot/.git/HEAD") | Should -BeTrue
            (Test-Path -LiteralPath "$testRoot/app.csproj") | Should -BeTrue
            (Test-Path -LiteralPath "$testRoot/tools/bin/script.sh") | Should -BeTrue
            (Test-Path -LiteralPath "$testRoot/vendored/dep/build/lib.so") | Should -BeTrue

            # idempotent: second run finds nothing to do
            $report2 = Get-ProjectCleanReport -Path $testRoot -PassThru
            $report2 | Should -BeNullOrEmpty
        }

        It 'throws when .git is not excluded and -Acknowledge is missing' {
            $script:testConfig = '{"directories":["node_modules"],"files":[],"exclude":[]}' | ConvertFrom-Json
            { Invoke-ProjectClean -Path $testRoot -Confirm:$false } | Should -Throw '*not in the exclude list*'
        }

        It 'proceeds when .git is not excluded but -Acknowledge is passed' {
            $script:testConfig = '{"directories":["node_modules"],"files":[],"exclude":[]}' | ConvertFrom-Json
            { Invoke-ProjectClean -Path $testRoot -Confirm:$false -Acknowledge -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Reparse points' {
        BeforeEach {
            # junction-target lives outside any rule, so it should survive
            New-Item -ItemType Directory -Path "$testRoot/junction-target" -Force | Out-Null
            Set-Content -LiteralPath "$testRoot/junction-target/keep-me.txt" -Value 'must-survive'

            # junction named node_modules → matches the rule
            New-Item -ItemType Junction -Path "$testRoot/link-node_modules" -Value "$testRoot/junction-target" | Out-Null
            # rename the junction so its leaf name is node_modules
            Rename-Item -LiteralPath "$testRoot/link-node_modules" -NewName 'node_modules'
        }

        It 'removes a junction as a link without touching the target' {
            (Test-Path -LiteralPath "$testRoot/node_modules") | Should -BeTrue
            Invoke-ProjectClean -Path $testRoot -Confirm:$false 6>$null
            (Test-Path -LiteralPath "$testRoot/node_modules") | Should -BeFalse
            (Test-Path -LiteralPath "$testRoot/junction-target/keep-me.txt") | Should -BeTrue
        }
    }

    Context 'Test-PathSafety' {
        It 'rejects the user profile' {
            { Invoke-ProjectClean -Path $env:USERPROFILE -Confirm:$false } | Should -Throw '*forbidden root*'
        }

        It 'rejects a drive root' {
            $driveRoot = [IO.Path]::GetPathRoot($testRoot)
            { Invoke-ProjectClean -Path $driveRoot -Confirm:$false } | Should -Throw '*forbidden root*'
        }
    }
}
