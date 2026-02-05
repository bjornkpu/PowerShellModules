@{
    ModuleVersion     = '0.1.0'
    GUID              = 'e8f7c9b1-4d5a-4e2f-9a8b-3c6d5e7f9a1b'
    Author            = 'Bjørn Opheim Undsveen'
    CompanyName       = 'Personal'
    Copyright         = '(c) 2025 Bjørn Opheim Undsveen. All rights reserved.'
    Description       = 'Intelligent test watcher with fuzzy search, auto-detection of Poetry/UV, and source path derivation'

    RootModule        = 'TestWatch.psm1'
    PowerShellVersion = '5.1'

    FunctionsToExport = @('Watch-Test')
    AliasesToExport   = @('tw')

    PrivateData       = @{
        PSData = @{
            Tags         = @('testing', 'pytest', 'watch', 'tdd', 'automation')
            LicenseUri   = 'https://github.com/bjornopheim/PowerShellModules/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/bjornopheim/PowerShellModules'
            ReleaseNotes = 'Initial release: Fuzzy test search, auto-runner detection, directory targeting'
        }
    }
}
