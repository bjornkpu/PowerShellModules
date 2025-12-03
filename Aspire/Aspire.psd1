@{
    ModuleVersion     = '0.1.0'
    GUID              = 'a3929750-c1e0-4da2-a71b-11e9e7e21872'
    Author            = 'Bjørn Kristian Punsvik'
    Description       = '.NET Aspire Dashboard container management utilities'
    PowerShellVersion = '7.4'
    RootModule        = 'Aspire.psm1'
    RequiredModules   = @(@{ModuleName = 'Shared'; ModuleVersion = '0.1.0' })
    FunctionsToExport = @('Start-AspireDashboard', 'Stop-AspireDashboard')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('dashboard', 'dashboard-start', 'dashboard-stop')

    # Gallery metadata
    PrivateData       = @{
        PSData = @{
            Tags         = @('aspire', 'dotnet', 'dashboard', 'docker', 'podman', 'containers')
            LicenseUri   = 'https://github.com/bjornkpu/PowerShellModules/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/bjornkpu/PowerShellModules'
            ReleaseNotes = 'Initial release with Start-AspireDashboard and Stop-AspireDashboard'
        }
    }
}
