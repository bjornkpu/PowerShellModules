@{
    ModuleVersion     = '0.1.0'
    GUID              = 'e41803f9-7cd8-41de-99f5-81721f2d7e3a'
    Author            = 'Bjørn Kristian Punsvik'
    Description       = 'Fabric CLI wrappers for AI-powered developer workflows'
    PowerShellVersion = '7.4'
    RootModule        = 'Fabric.psm1'
    RequiredModules   = @()
    FunctionsToExport = @('Invoke-FabricCommitMessage')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('fcm')

    # Gallery metadata
    PrivateData       = @{
        PSData = @{
            Tags         = @('fabric', 'ai', 'commit-message', 'git', 'automation')
            LicenseUri   = 'https://github.com/bjornkpu/PowerShellModules/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/bjornkpu/PowerShellModules'
            ReleaseNotes = 'Initial release with Invoke-FabricCommitMessage'
        }
    }
}
