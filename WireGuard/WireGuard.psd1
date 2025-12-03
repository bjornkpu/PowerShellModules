@{
    ModuleVersion     = '0.1.0'
    GUID              = '91b3fda0-67b8-4354-8b65-81f69e72c41c'
    Author            = 'Bjørn Kristian Punsvik'
    Description       = 'WireGuard VPN tunnel management utilities'
    PowerShellVersion = '7.4'
    RootModule        = 'WireGuard.psm1'
    RequiredModules   = @(@{ModuleName = 'Shared'; ModuleVersion = '0.1.0' })
    FunctionsToExport = @('Start-WireGuardTunnel', 'Stop-WireGuardTunnel', 'Get-WireGuardStatus', 'Restart-WireGuardTunnel', 'Set-WireGuardStartupMode')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('wgstart', 'wgstop', 'wgstatus', 'wgrestart', 'wgstartup')
}
