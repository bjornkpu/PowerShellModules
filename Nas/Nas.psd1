@{
    ModuleVersion     = '0.1.0'
    RootModule        = 'Nas.psm1'

    GUID              = 'a3b7c1d4-5e2f-4a8b-9d6c-1f3e5a7b9c2d'

    Author            = 'Bjørn Olav Punsvik'
    CompanyName       = 'Personal'
    Copyright         = '(c) 2026 Bjørn Olav Punsvik. All rights reserved.'
    Description       = 'NAS server interaction module. Mount and unmount SMB shares with stored credentials.'

    PowerShellVersion = '5.1'

    RequiredModules   = @('Shared')

    FunctionsToExport = @('Mount-NasShare', 'Dismount-NasShare')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('nas', 'smb', 'network', 'storage')
            LicenseUri   = 'https://github.com/bjornpunsvik/PowerShellModules/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/bjornpunsvik/PowerShellModules'
            ReleaseNotes = 'Initial release with SMB share mount/unmount support'
        }
    }
}
