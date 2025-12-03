@{
    ModuleVersion     = '0.1.0'
    GUID              = '2089880a-7f95-427a-8e2b-e17debed1a9e'
    Author            = 'Bjørn Kristian Punsvik'
    Description       = 'Project and component navigation system with auto-start capabilities'
    PowerShellVersion = '7.4'
    RootModule        = 'ProjectManager.psm1'
    RequiredModules   = @(@{ModuleName = 'Shared'; ModuleVersion = '0.1.0' })
    FunctionsToExport = @('Start-Project', 'Start-ProjectComponent', 'Show-Projects')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('sd', 'sdl')
}
