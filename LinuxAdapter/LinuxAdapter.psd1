@{
    ModuleVersion     = '1.0.0'
    GUID              = 'ddd6b15b-58d3-4a6e-9373-c2512306cbaf'
    Author            = 'Bjørn Kristian Punsvik'
    Description       = 'Provides familiar Linux/Bash command aliases and wrappers for PowerShell, making the transition between Linux and Windows seamless.'
    PowerShellVersion = '7.4'
    RootModule        = 'LinuxAdapter.psm1'
    RequiredModules   = @()
    FunctionsToExport = @('Watch-Command')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('watch')
}
