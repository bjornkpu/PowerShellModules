@{
    ModuleVersion     = '0.1.0'
    RootModule        = 'TimeTrack.psm1'

    GUID              = 'f8a9c3d2-4b1e-4f7a-9c8d-3e2b1a4f5c6d'

    Author            = 'Bjørn Olav Punsvik'
    CompanyName       = 'Personal'
    Copyright         = '(c) 2026 Bjørn Olav Punsvik. All rights reserved.'
    Description       = 'Time tracking automation module with pluggable backends (Toggl) and multi-system reporting (TimeReg, xledger, Enova). Automates lunch break insertion and weekly timesheet management.'

    PowerShellVersion = '5.1'

    RequiredModules   = @('Shared')

    FunctionsToExport = @('Invoke-TimeTrack')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('tt')

    PrivateData       = @{
        PSData = @{
            Tags         = @('timetracking', 'toggl', 'automation', 'reporting', 'timesheet')
            LicenseUri   = 'https://github.com/bjornpunsvik/PowerShellModules/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/bjornpunsvik/PowerShellModules'
            ReleaseNotes = 'Initial release with Toggl backend support, lunch break automation, and multi-system reporting'
        }
    }
}
