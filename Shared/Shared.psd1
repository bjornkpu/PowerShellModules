@{
    ModuleVersion     = '1.0.0'
    GUID              = 'beb2f225-a52f-463f-b55d-d15dcf48b06d'
    Author            = 'Bjørn Kristian Punsvik'
    CompanyName       = 'Personal'
    Copyright         = '(c) 2025 Bjørn Kristian Punsvik. All rights reserved.'
    Description       = 'Shared utilities for PowerShell module configuration management'
    PowerShellVersion = '7.4'
    RootModule        = 'Shared.psm1'
    FunctionsToExport = @('Initialize-ModuleConfig', 'Get-ModuleConfig', 'Test-ConfigSchema', 'Reset-ModuleConfig')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('configuration', 'module', 'utilities', 'json-schema')
            LicenseUri   = 'https://github.com/bjornkpu/PowerShellModules/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/bjornkpu/PowerShellModules'
            ReleaseNotes = 'Initial release - Config management utilities for PowerShell modules'
        }
    }
}
