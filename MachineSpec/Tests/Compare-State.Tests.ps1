BeforeAll {
    Import-Module "$PSScriptRoot\..\MachineSpec.psd1" -Force
}

Describe 'Compare-State' {
    BeforeEach {
        $script:emptySpec = [pscustomobject]@{
            Winget       = @()
            Modules      = @()
            Repositories = @()
        }
    }

    Context 'WingetPackage' {
        It 'plans Install when not present' {
            $spec = [pscustomobject]@{
                Winget       = @([pscustomobject]@{ Id = 'Git.Git'; Version = $null; Source = 'winget' })
                Modules      = @()
                Repositories = @()
            }
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec } {
                Compare-State -Spec $s -WingetState @() -ModuleState @() -RepoState @()
            }
            @($plan).Count | Should -Be 1
            @($plan)[0].Action | Should -Be 'Install'
            @($plan)[0].Kind   | Should -Be 'WingetPackage'
        }

        It 'plans Skip when present and no version pin' {
            $spec = [pscustomobject]@{
                Winget       = @([pscustomobject]@{ Id = 'Git.Git'; Version = $null; Source = 'winget' })
                Modules      = @()
                Repositories = @()
            }
            $current = @([pscustomobject]@{ Id = 'Git.Git'; Version = '2.43.0'; Source = 'winget' })
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec; c = $current } {
                Compare-State -Spec $s -WingetState $c -ModuleState @() -RepoState @()
            }
            @($plan)[0].Action | Should -Be 'Skip'
        }

        It 'plans Upgrade when version pin mismatches' {
            $spec = [pscustomobject]@{
                Winget       = @([pscustomobject]@{ Id = 'Git.Git'; Version = '2.43.0'; Source = 'winget' })
                Modules      = @()
                Repositories = @()
            }
            $current = @([pscustomobject]@{ Id = 'Git.Git'; Version = '2.40.0'; Source = 'winget' })
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec; c = $current } {
                Compare-State -Spec $s -WingetState $c -ModuleState @() -RepoState @()
            }
            @($plan)[0].Action      | Should -Be 'Upgrade'
            @($plan)[0].FromVersion | Should -Be '2.40.0'
            @($plan)[0].ToVersion   | Should -Be '2.43.0'
        }

        It 'ignores extras (no prune)' {
            $current = @([pscustomobject]@{ Id = 'Some.Extra'; Version = '1.0'; Source = 'winget' })
            $plan = InModuleScope MachineSpec -Parameters @{ s = $script:emptySpec; c = $current } {
                Compare-State -Spec $s -WingetState $c -ModuleState @() -RepoState @()
            }
            @($plan).Count | Should -Be 0
        }
    }

    Context 'PSModule' {
        It 'plans Install when not present' {
            $spec = [pscustomobject]@{
                Winget       = @()
                Modules      = @([pscustomobject]@{ Name = 'Pester'; Version = $null; Scope = 'CurrentUser' })
                Repositories = @()
            }
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec } {
                Compare-State -Spec $s -WingetState @() -ModuleState @() -RepoState @()
            }
            @($plan)[0].Action | Should -Be 'Install'
            @($plan)[0].Kind   | Should -Be 'PSModule'
        }

        It 'plans Upgrade on pinned version mismatch' {
            $spec = [pscustomobject]@{
                Winget       = @()
                Modules      = @([pscustomobject]@{ Name = 'Pester'; Version = '5.7.1'; Scope = 'CurrentUser' })
                Repositories = @()
            }
            $current = @([pscustomobject]@{ Name = 'Pester'; Version = '5.5.0'; Scope = 'CurrentUser' })
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec; c = $current } {
                Compare-State -Spec $s -WingetState @() -ModuleState $c -RepoState @()
            }
            @($plan)[0].Action | Should -Be 'Upgrade'
        }
    }

    Context 'PSRepository' {
        It 'plans Install when not registered' {
            $spec = [pscustomobject]@{
                Winget       = @()
                Modules      = @()
                Repositories = @([pscustomobject]@{ Name = 'PSGallery'; Trusted = $true; SourceLocation = $null })
            }
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec } {
                Compare-State -Spec $s -WingetState @() -ModuleState @() -RepoState @()
            }
            @($plan)[0].Action | Should -Be 'Install'
            @($plan)[0].Kind   | Should -Be 'PSRepository'
        }

        It 'plans Upgrade on trust mismatch' {
            $spec = [pscustomobject]@{
                Winget       = @()
                Modules      = @()
                Repositories = @([pscustomobject]@{ Name = 'PSGallery'; Trusted = $true; SourceLocation = $null })
            }
            $current = @([pscustomobject]@{ Name = 'PSGallery'; Trusted = $false; SourceLocation = $null })
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec; c = $current } {
                Compare-State -Spec $s -WingetState @() -ModuleState @() -RepoState $c
            }
            @($plan)[0].Action | Should -Be 'Upgrade'
            @($plan)[0].Reason | Should -Match 'trust'
        }
    }

    Context 'DotNetTool' {
        It 'plans Install when not present' {
            $spec = [pscustomobject]@{
                Winget = @(); Modules = @(); Repositories = @()
                DotnetTools = @([pscustomobject]@{ Id = 'dotnet-ef'; Version = $null })
                UvTools = @(); NpmGlobals = @()
            }
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec } {
                Compare-State -Spec $s -WingetState @() -ModuleState @() -RepoState @()
            }
            @($plan)[0].Action | Should -Be 'Install'
            @($plan)[0].Kind   | Should -Be 'DotNetTool'
        }
        It 'plans Upgrade on pinned version mismatch' {
            $spec = [pscustomobject]@{
                Winget = @(); Modules = @(); Repositories = @()
                DotnetTools = @([pscustomobject]@{ Id = 'dotnet-ef'; Version = '8.0.0' })
                UvTools = @(); NpmGlobals = @()
            }
            $current = @([pscustomobject]@{ Id = 'dotnet-ef'; Version = '7.0.0' })
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec; c = $current } {
                Compare-State -Spec $s -WingetState @() -ModuleState @() -RepoState @() -DotnetState $c
            }
            @($plan)[0].Action | Should -Be 'Upgrade'
        }
    }

    Context 'UvTool' {
        It 'plans Install when not present' {
            $spec = [pscustomobject]@{
                Winget = @(); Modules = @(); Repositories = @(); DotnetTools = @()
                UvTools = @([pscustomobject]@{ Name = 'ruff'; Version = $null })
                NpmGlobals = @()
            }
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec } {
                Compare-State -Spec $s -WingetState @() -ModuleState @() -RepoState @()
            }
            @($plan)[0].Action | Should -Be 'Install'
            @($plan)[0].Kind   | Should -Be 'UvTool'
        }
    }

    Context 'NpmGlobal' {
        It 'plans Skip when present and no pin' {
            $spec = [pscustomobject]@{
                Winget = @(); Modules = @(); Repositories = @(); DotnetTools = @(); UvTools = @()
                NpmGlobals = @([pscustomobject]@{ Name = 'typescript'; Version = $null })
            }
            $current = @([pscustomobject]@{ Name = 'typescript'; Version = '5.4.0' })
            $plan = InModuleScope MachineSpec -Parameters @{ s = $spec; c = $current } {
                Compare-State -Spec $s -WingetState @() -ModuleState @() -RepoState @() -NpmState $c
            }
            @($plan)[0].Action | Should -Be 'Skip'
        }
    }

    It 'preserves order: repos, winget, modules' {
        $spec = [pscustomobject]@{
            Winget       = @([pscustomobject]@{ Id = 'Git.Git'; Version = $null; Source = 'winget' })
            Modules      = @([pscustomobject]@{ Name = 'Pester'; Version = $null; Scope = 'CurrentUser' })
            Repositories = @([pscustomobject]@{ Name = 'PSGallery'; Trusted = $true; SourceLocation = $null })
        }
        $plan = InModuleScope MachineSpec -Parameters @{ s = $spec } {
            Compare-State -Spec $s -WingetState @() -ModuleState @() -RepoState @()
        }
        @($plan)[0].Kind | Should -Be 'PSRepository'
        @($plan)[1].Kind | Should -Be 'WingetPackage'
        @($plan)[2].Kind | Should -Be 'PSModule'
    }
}
