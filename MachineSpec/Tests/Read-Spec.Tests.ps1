BeforeAll {
    Import-Module "$PSScriptRoot\..\MachineSpec.psd1" -Force
    $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("MachineSpecTests_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tempDir | Out-Null

    function New-SpecFile {
        param([string]$Content)
        $path = Join-Path $script:tempDir ("spec_" + [guid]::NewGuid().ToString('N') + ".yaml")
        Set-Content -LiteralPath $path -Value $Content -Encoding UTF8
        $path
    }
}

AfterAll {
    if (Test-Path -LiteralPath $script:tempDir) {
        Remove-Item -LiteralPath $script:tempDir -Recurse -Force
    }
}

Describe 'Read-Spec' {

    It 'parses a minimal valid spec' {
        $path = New-SpecFile "version: 1`n"
        $spec = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p }
        $spec.Version | Should -Be 1
        @($spec.Winget).Count | Should -Be 0
        @($spec.Modules).Count | Should -Be 0
        @($spec.Repositories).Count | Should -Be 0
    }

    It 'expands bare-string winget shorthand and parses pinned version' {
        $path = New-SpecFile @"
version: 1
winget:
  packages:
    - Git.Git
    - id: Microsoft.PowerShell
      version: 7.4.6
"@
        $spec = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p }
        @($spec.Winget).Count | Should -Be 2
        @($spec.Winget)[0].Id | Should -Be 'Git.Git'
        @($spec.Winget)[0].Version | Should -BeNullOrEmpty
        @($spec.Winget)[0].Source | Should -Be 'winget'
        @($spec.Winget)[1].Id | Should -Be 'Microsoft.PowerShell'
        @($spec.Winget)[1].Version | Should -Be '7.4.6'
    }

    It 'expands bare-string module shorthand and respects scope' {
        $path = New-SpecFile @"
version: 1
powershell:
  modules:
    - Pester
    - name: posh-git
      scope: AllUsers
"@
        $spec = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p }
        @($spec.Modules).Count | Should -Be 2
        @($spec.Modules)[0].Name | Should -Be 'Pester'
        @($spec.Modules)[0].Scope | Should -Be 'CurrentUser'
        @($spec.Modules)[1].Scope | Should -Be 'AllUsers'
    }

    It 'parses repositories' {
        $path = New-SpecFile @"
version: 1
powershell:
  repositories:
    - name: PSGallery
      trusted: true
"@
        $spec = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p }
        @($spec.Repositories).Count | Should -Be 1
        @($spec.Repositories)[0].Name | Should -Be 'PSGallery'
        @($spec.Repositories)[0].Trusted | Should -Be $true
    }

    It 'rejects missing version key' {
        $path = New-SpecFile "winget:`n  packages:`n    - Git.Git`n"
        { InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p } } |
            Should -Throw -ExpectedMessage '*missing required root key*'
    }

    It 'rejects unsupported version' {
        $path = New-SpecFile "version: 99`n"
        { InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p } } |
            Should -Throw -ExpectedMessage '*Unsupported spec version*'
    }

    It 'rejects invalid module scope' {
        $path = New-SpecFile @"
version: 1
powershell:
  modules:
    - name: posh-git
      scope: Bogus
"@
        { InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p } } |
            Should -Throw -ExpectedMessage '*invalid scope*'
    }

    It 'warns on unknown root keys' {
        $path = New-SpecFile @"
version: 1
fonts:
  - Cascadia Code
"@
        $warnings = @()
        $null = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p } -WarningVariable warnings -WarningAction SilentlyContinue
        ($warnings -join '|') | Should -Match 'fonts'
    }

    It 'parses dotnet tools (shorthand + pinned)' {
        $path = New-SpecFile @"
version: 1
dotnet:
  tools:
    - dotnet-ef
    - id: csharprepl
      version: 0.6.4
"@
        $spec = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p }
        @($spec.DotnetTools).Count | Should -Be 2
        @($spec.DotnetTools)[0].Id | Should -Be 'dotnet-ef'
        @($spec.DotnetTools)[0].Version | Should -BeNullOrEmpty
        @($spec.DotnetTools)[1].Version | Should -Be '0.6.4'
    }

    It 'parses uv tools (shorthand + pinned)' {
        $path = New-SpecFile @"
version: 1
uv:
  tools:
    - ruff
    - name: black
      version: 24.10.0
"@
        $spec = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p }
        @($spec.UvTools).Count | Should -Be 2
        @($spec.UvTools)[0].Name | Should -Be 'ruff'
        @($spec.UvTools)[1].Version | Should -Be '24.10.0'
    }

    It 'parses npm globals (shorthand + pinned)' {
        $path = New-SpecFile @"
version: 1
npm:
  globals:
    - typescript
    - name: pnpm
      version: 9.15.0
"@
        $spec = InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p }
        @($spec.NpmGlobals).Count | Should -Be 2
        @($spec.NpmGlobals)[0].Name | Should -Be 'typescript'
        @($spec.NpmGlobals)[1].Version | Should -Be '9.15.0'
    }

    It 'rejects winget entry missing id' {
        $path = New-SpecFile @"
version: 1
winget:
  packages:
    - version: 1.0
"@
        { InModuleScope MachineSpec -Parameters @{ p = $path } { Read-Spec -Path $p } } |
            Should -Throw -ExpectedMessage "*missing required 'id'*"
    }
}
