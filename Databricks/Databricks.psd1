@{
    ModuleVersion     = '0.1.0'
    GUID              = 'fb0f7a43-d25a-4a77-88e3-7675f6d2c663'
    Author            = 'Bjørn Kristian Punsvik'
    Description       = 'Databricks CLI wrappers and Python development tools'
    PowerShellVersion = '7.4'
    RootModule        = 'Databricks.psm1'
    RequiredModules   = @(@{ModuleName = 'Shared'; ModuleVersion = '0.1.0' })
    FunctionsToExport = @('Invoke-DatabricksCommand', 'Deploy-PythonPackage')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('d')
}
