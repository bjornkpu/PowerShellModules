@{
    ModuleVersion     = '0.1.0'
    GUID              = '2dad7a02-da0c-4c18-b412-77e74b25e599'
    Author            = 'Bjørn Kristian Punsvik'
    CompanyName       = 'Personal'
    Copyright         = '(c) 2026 Bjørn Kristian Punsvik. All rights reserved.'
    Description       = 'Declarative Windows machine state: capture and reproduce installed winget packages, PS modules, and PS repositories from a single YAML file.'

    RootModule        = 'MachineSpec.psm1'
    PowerShellVersion = '7.4'

    RequiredModules   = @(
        @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.7' }
    )

    FunctionsToExport = @('Export-MachineSpec', 'Install-MachineSpec', 'Test-MachineSpec')
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('winget', 'declarative', 'config', 'nix-style', 'devmachine', 'yaml')
            LicenseUri   = 'https://github.com/bjornopheim/PowerShellModules/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/bjornopheim/PowerShellModules'
            ReleaseNotes = 'Initial release: Export, Install, Test commands for winget + PSGallery + PS repositories.'
        }
    }
}
