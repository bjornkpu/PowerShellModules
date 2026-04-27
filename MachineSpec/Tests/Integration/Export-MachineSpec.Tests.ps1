BeforeAll {
    Import-Module "$PSScriptRoot\..\..\MachineSpec.psd1" -Force
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("MachineSpecExportInt_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tempDir | Out-Null
}

AfterAll {
    if (Test-Path -LiteralPath $script:tempDir) {
        Remove-Item -LiteralPath $script:tempDir -Recurse -Force
    }
}

Describe 'Export-MachineSpec (integration)' -Tag 'Integration' {

    It 'exports current machine state and round-trips' {
        $path = Join-Path $script:tempDir 'snapshot.yaml'
        Export-MachineSpec -Path $path -Force -InformationAction SilentlyContinue

        Test-Path -LiteralPath $path | Should -Be $true
        $reread = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p }
        $reread.Version | Should -Be 1
        # at least PSGallery should be registered
        @($reread.Repositories | Where-Object Name -EQ 'PSGallery').Count | Should -BeGreaterThan 0
    }

    It 'refuses to overwrite without -Force' {
        $path = Join-Path $script:tempDir 'noforce.yaml'
        Export-MachineSpec -Path $path -InformationAction SilentlyContinue
        { Export-MachineSpec -Path $path -InformationAction SilentlyContinue } |
            Should -Throw -ExpectedMessage '*already exists*'
    }
}
