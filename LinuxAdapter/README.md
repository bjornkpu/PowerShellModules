# LinuxAdapter

PowerShell module that provides familiar Linux/Bash command aliases and wrappers for Windows PowerShell users who frequently work with Linux systems.

## Overview

If you're a Linux administrator working on Windows, you know the frustration of typing Linux commands only to get "command not found" errors. This module bridges that gap by providing PowerShell implementations of common Linux CLI utilities with the same syntax and behavior you're used to.

## Installation

### Manual Installation

1. Clone or download this repository
2. Ensure the `LinuxAdapter` folder is in your PowerShell modules path:
   - `C:\Users\{username}\PowerShellModules\LinuxAdapter`
3. Import the module:

   ```powershell
   Import-Module LinuxAdapter
   ```

## Available Commands

### `watch` - Execute Commands Repeatedly

Monitor command output with automatic refresh, just like the Linux `watch` command.

**Syntax:**

```powershell
watch [-Interval <seconds>] [-Differences] <command>
```

**Parameters:**

- `-Interval` (alias: `-n`, `-interval`): Seconds between updates (default: 2, range: 0.1-3600)
- `-Differences` (alias: `-d`, `-diff`): Highlight changes between updates
- `<command>`: PowerShell script block to execute

**Examples:**

Monitor date/time (updates every 2 seconds):

```powershell
watch { Get-Date }
```

Monitor top 10 processes (updates every 5 seconds):

```powershell
watch -Interval 5 { Get-Process | Select-Object -First 10 }
```

Count running services (updates every second):

```powershell
watch -n 1 { Get-Service | Where-Object Status -eq 'Running' | Measure-Object | Select-Object -ExpandProperty Count }
```

Monitor disk space with differences highlighted:

```powershell
watch -d -n 5 { Get-PSDrive -PSProvider FileSystem }
```

Monitor network connections:

```powershell
watch -Interval 3 { Get-NetTCPConnection | Where-Object State -eq 'Established' | Select-Object LocalAddress, RemoteAddress, State }
```

**Tips:**

- Press `Ctrl+C` to stop watching
- Use script blocks `{ }` to wrap your commands
- Compatible with any PowerShell cmdlet or pipeline
- The `-Differences` flag highlights lines that changed since the last iteration

## Coming Soon

More Linux command adapters are planned:

- `tail` - Follow file content (like `Get-Content -Tail -Wait` but with Linux syntax)
- `grep` - Pattern matching (wrapper for `Select-String`)
- `find` - File search (wrapper for `Get-ChildItem` recursion)
- `ps` - Process listing (wrapper for `Get-Process`)
- `kill` - Process termination (wrapper for `Stop-Process`)
- `df` - Disk space (wrapper for `Get-PSDrive`)
- `du` - Disk usage (wrapper for file size calculations)
- `which` - Command location (wrapper for `Get-Command`)

## Design Philosophy

This module follows the PowerShell Modules project principles:

- **No configuration required** - Works out of the box
- **Fast loading** - Minimal import time
- **PowerShell-native** - Leverages existing cmdlets where possible
- **Linux-familiar** - Matches Linux command syntax and behavior
- **Open source** - No hardcoded paths or company-specific values

## Contributing

Have a Linux command you miss on Windows? Contributions welcome!

When adding new commands:

1. Create a function in `Public/` following PowerShell naming conventions
2. Add appropriate aliases to match Linux command names
3. Update the manifest's `FunctionsToExport` and `AliasesToExport`
4. Document in this README

## Why Not Just Use WSL?

WSL is great, but sometimes you need to stay in PowerShell for:

- Windows-specific administration tasks
- Integration with PowerShell scripts and modules
- Running both Windows and Linux-style commands in the same session
- Familiarity without context switching

This module gives you the best of both worlds.

## License

See [LICENSE](../LICENSE) file in the repository root.

## Author

Bjorn Kpu - [GitHub](https://github.com/bjornkpu/PowerShellModules)
