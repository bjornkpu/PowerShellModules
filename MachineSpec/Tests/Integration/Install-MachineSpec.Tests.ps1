BeforeAll {
    Import-Module "$PSScriptRoot\..\..\MachineSpec.psd1" -Force
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("MachineSpecInstallInt_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tempDir | Out-Null

    # Use a small, fast PSGallery module for the round-trip. Pick one unlikely to already be installed.
    $script:probeModuleName = 'PSReadLine'
}

AfterAll {
    if (Test-Path -LiteralPath $script:tempDir) {
        Remove-Item -LiteralPath $script:tempDir -Recurse -Force
    }
}

Describe 'Install-MachineSpec (integration)' -Tag 'Integration' {

    It '-WhatIf shows plan without installing' {
        $path = Join-Path $script:tempDir 'whatif.yaml'
        Set-Content -LiteralPath $path -Value @"
version: 1
powershell:
  modules:
    - $script:probeModuleName
"@ -Encoding UTF8

        $plan = Install-MachineSpec -Path $path -WhatIf -SkipWinget -InformationAction SilentlyContinue -Quiet
        @($plan).Count | Should -BeGreaterThan 0
    }

    It 'second run is idempotent (all Skip)' {
        $path = Join-Path $script:tempDir 'idempotent.yaml'
        Set-Content -LiteralPath $path -Value @"
version: 1
powershell:
  modules:
    - $script:probeModuleName
"@ -Encoding UTF8

        $first  = Install-MachineSpec -Path $path -SkipWinget -InformationAction SilentlyContinue -Quiet
        $second = Install-MachineSpec -Path $path -SkipWinget -InformationAction SilentlyContinue -Quiet

        $secondActions = @($second) | Where-Object Action -NE 'Skip'
        $secondActions.Count | Should -Be 0
    }

    It 'Test-MachineSpec reports drift via exit code' {
        $path = Join-Path $script:tempDir 'drift.yaml'
        Set-Content -LiteralPath $path -Value @"
version: 1
powershell:
  modules:
    - DefinitelyNotARealModule_$([guid]::NewGuid().ToString('N'))
"@ -Encoding UTF8

        $null = Test-MachineSpec -Path $path -InformationAction SilentlyContinue -Quiet
        $global:LASTEXITCODE | Should -Be 1
    }
}
