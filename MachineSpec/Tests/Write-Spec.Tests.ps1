BeforeAll {
    Import-Module "$PSScriptRoot\..\MachineSpec.psd1" -Force
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("MachineSpecWriteTests_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tempDir | Out-Null

    function New-Spec {
        [pscustomobject]@{
            Version      = 1
            Winget       = @(
                [pscustomobject]@{ Id = 'Microsoft.PowerShell'; Version = $null;    Source = 'winget' }
                [pscustomobject]@{ Id = 'Git.Git';              Version = '2.43.0'; Source = 'winget' }
                [pscustomobject]@{ Id = 'JetBrains.Rider';      Version = $null;    Source = 'winget' }
            )
            Modules      = @(
                [pscustomobject]@{ Name = 'Terminal-Icons'; Version = $null;    Scope = 'CurrentUser' }
                [pscustomobject]@{ Name = 'Pester';         Version = '5.7.1';  Scope = 'CurrentUser' }
            )
            Repositories = @(
                [pscustomobject]@{ Name = 'PSGallery'; Trusted = $true; SourceLocation = $null }
            )
            DotnetTools  = @(
                [pscustomobject]@{ Id = 'dotnet-ef'; Version = $null }
                [pscustomobject]@{ Id = 'csharprepl'; Version = '0.6.4' }
            )
            UvTools      = @(
                [pscustomobject]@{ Name = 'ruff'; Version = $null }
            )
            NpmGlobals   = @(
                [pscustomobject]@{ Name = 'typescript'; Version = $null }
                [pscustomobject]@{ Name = 'pnpm'; Version = '9.15.0' }
            )
        }
    }
}

AfterAll {
    if (Test-Path -LiteralPath $script:tempDir) {
        Remove-Item -LiteralPath $script:tempDir -Recurse -Force
    }
}

Describe 'Write-Spec' {

    It 'writes YAML and round-trips through Read-Spec' {
        $path = Join-Path $script:tempDir 'roundtrip.yaml'
        $spec = New-Spec
        InModuleScope MachineSpec -Parameters @{ s = $spec; p = $path } { Write-Spec -Spec $s -Path $p -Force }

        Test-Path -LiteralPath $path | Should -Be $true
        $reread = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p }

        @($reread.Winget).Count       | Should -Be 3
        @($reread.Modules).Count      | Should -Be 2
        @($reread.Repositories).Count | Should -Be 1
        @($reread.DotnetTools).Count  | Should -Be 2
        @($reread.UvTools).Count      | Should -Be 1
        @($reread.NpmGlobals).Count   | Should -Be 2
    }

    It 'sorts winget alphabetically by id' {
        $path = Join-Path $script:tempDir 'sorted.yaml'
        $spec = New-Spec
        InModuleScope MachineSpec -Parameters @{ s = $spec; p = $path } { Write-Spec -Spec $s -Path $p -Force }

        $yaml = Get-Content -LiteralPath $path -Raw
        $gitIdx    = $yaml.IndexOf('Git.Git')
        $jetIdx    = $yaml.IndexOf('JetBrains.Rider')
        $msIdx     = $yaml.IndexOf('Microsoft.PowerShell')
        $gitIdx | Should -BeLessThan $jetIdx
        $jetIdx | Should -BeLessThan $msIdx
    }

    It 'omits null/default fields' {
        $path = Join-Path $script:tempDir 'minimal.yaml'
        $spec = New-Spec
        InModuleScope MachineSpec -Parameters @{ s = $spec; p = $path } { Write-Spec -Spec $s -Path $p -Force }

        $yaml = Get-Content -LiteralPath $path -Raw
        # Microsoft.PowerShell has no version pin -> "version:" should not appear directly under it
        $yaml | Should -Not -Match 'scope:\s*CurrentUser'
    }

    It 'refuses to overwrite without -Force' {
        $path = Join-Path $script:tempDir 'noforce.yaml'
        Set-Content -LiteralPath $path -Value 'sentinel' -Encoding UTF8
        $spec = New-Spec
        { InModuleScope MachineSpec -Parameters @{ s = $spec; p = $path } { Write-Spec -Spec $s -Path $p } } |
            Should -Throw -ExpectedMessage '*already exists*'
    }
}
