# PowerShell Modules

This repository contains a collection of PowerShell modules designed to enhance productivity and streamline various tasks. Each module is organized in its own directory, complete with documentation and examples.

## Installation

### First-Time Setup

1. **Clone the repository** to your PowerShell modules path:

   ```powershell
   cd $HOME
   git clone https://github.com/bjornkpu/PowerShellModules.git
   ```

2. **Add to PSModulePath**:

   ```powershell
   cd PowerShellModules
   .\Add-ModulePath.ps1
   ```

3. **Restart PowerShell** for the module path to take effect.

4. **Use the modules** - they auto-load when you use their commands:

   ```powershell
   # Just use the commands - no import needed!
   d start
   wgstart
   sd myproject
   ```

   **Optional:** Manually import if you want them pre-loaded:

   ```powershell
   Import-Module Databricks
   Import-Module WireGuard
   ```

   Or add to `$PROFILE` for automatic loading on startup (rarely needed).

## Updating Modules

After pulling new changes from the repository:

```powershell
# Navigate to the repository
cd $HOME\PowerShellModules

# Pull latest changes
git pull

# Reload modules in current session
Remove-Module Databricks -Force -ErrorAction SilentlyContinue
Import-Module Databricks -Force

```

## Removing Modules

To remove a module:

```powershell
# Remove from current session
Remove-Module ModuleName
```

## Available Modules

- **Databricks** - CLI for Databricks cluster management and package deployment
- **WireGuard** - VPN tunnel management with Windows service control
- **ProjectManager** - Workspace navigation with fuzzy matching and auto-start
- **ProjectClean** - Configurable cleaner that prunes build artifacts and dependency caches from project trees
- **Aspire** - .NET Aspire dashboard lifecycle management
- **Fabric** - Microsoft Fabric AI integration (commit messages)
- **LinuxAdapter** - Unix-like commands for PowerShell (e.g., `watch`)
- **SparkSchema** - Spark schema conversion utilities
- **Shared** - Foundation module providing config management for all modules
