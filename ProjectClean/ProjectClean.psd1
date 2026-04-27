@{
    ModuleVersion     = '0.1.0'
    GUID              = '1e318986-bddf-48e0-804d-381f635c1c75'
    Author            = 'Bjørn Kristian Punsvik'
    Description       = 'Configurable cleaner that prunes build artifacts and dependency caches from project trees'
    PowerShellVersion = '7.4'
    RootModule        = 'ProjectClean.psm1'
    RequiredModules   = @(@{ModuleName = 'Shared'; ModuleVersion = '0.1.0' })
    FunctionsToExport = @('Invoke-ProjectClean', 'Get-ProjectCleanReport')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
