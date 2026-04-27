# MachineSpec

Declarative Windows machine state. One YAML file describes the winget packages, PowerShell modules, and PSGallery repositories that should be installed; three commands round-trip a machine to/from that state.

## Requirements

- PowerShell 7.4+
- Windows with `winget` on PATH
- `powershell-yaml` (auto-installed via the manifest's `RequiredModules` declaration)

## Commands

| Command | Purpose |
| --- | --- |
| `Export-MachineSpec` | Snapshot current machine to a YAML file |
| `Install-MachineSpec` | Bring a machine into compliance with a YAML file |
| `Test-MachineSpec` | Diff the YAML against the current machine; exit 1 on drift |

## Quick start

```powershell
Import-Module MachineSpec

# Capture this machine
Export-MachineSpec -Path .\machine.yaml

# Move that file to a new machine, then converge
Install-MachineSpec -Path .\machine.yaml

# Audit drift later
Test-MachineSpec -Path .\machine.yaml   # exit 0 = clean, exit 1 = drift
```

See [examples/machine.yaml](examples/machine.yaml) for a full schema example.

## Supported sections

- `winget:` — winget packages
- `powershell:` — registered PSGallery repositories + installed PowerShell modules
- `dotnet:` — `dotnet tool install -g` global tools
- `uv:` — `uv tool install` Python tools
- `npm:` — `npm install -g` global packages

## Behavior notes

- **Latest by default.** Pinning is opt-in per item via `version:`.
- **No prune in v1.** Items installed on the machine but absent from the YAML are ignored — `Test-MachineSpec` does not report them as drift.
- **Order of operations on install:** PS repositories → winget → PowerShell modules → dotnet tools → uv tools → npm globals. Base interpreters (dotnet SDK, node, uv) should sit in `winget:` so they install before their ecosystem tools.
- **Fail-fast on missing base tool.** If the spec lists `dotnet:`/`uv:`/`npm:` items but the corresponding CLI is missing from PATH, install aborts with a clear error pointing at the winget id to fix it.
- **AllUsers scope** for PS modules requires running elevated; the command fails fast with a clear error if not elevated.
- **Comments are not preserved** on `Export-MachineSpec`. The underlying `powershell-yaml` library strips them. Either keep your handcrafted YAML separate from exports or accept the loss on round-trip.

## Output

Every executed action emits a `[pscustomobject]` on the success stream — pipe to `Where-Object`, `Format-Table`, etc. A human-readable summary goes to the Information stream; suppress with `-Quiet`.

## Tests

```powershell
# Unit only
Invoke-Pester -Path .\MachineSpec\Tests -ExcludeTagFilter Integration

# With integration (real PSGallery installs of small probe modules)
Invoke-Pester -Path .\MachineSpec\Tests -TagFilter Integration
```
