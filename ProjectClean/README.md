# ProjectClean Module

Configurable cleaner that walks a directory tree and removes build artifacts and dependency caches (`node_modules`, `.venv`, `bin`, `obj`, `target`, etc.) so projects can be archived efficiently.

## Commands

| Command | Description |
|---|---|
| `Invoke-ProjectClean` | Walk a tree and remove configured artifacts |
| `Get-ProjectCleanReport` | Same walk, no deletion — print a report |

## Configuration

Config file: `~/.config/ProjectClean/config.json` (auto-created from defaults on first run).

```json
{
  "directories": [
    "node_modules", ".venv", "venv", "__pycache__",
    ".pytest_cache", ".mypy_cache", ".ruff_cache",
    "dist", "build",
    ".next", ".nuxt", ".turbo", ".gradle", ".idea/shelf",
    { "name": "bin",    "requires": ["*.csproj", "*.fsproj", "*.vbproj", "*.sln", "Directory.Build.props"] },
    { "name": "obj",    "requires": ["*.csproj", "*.fsproj", "*.vbproj", "*.sln", "Directory.Build.props"] },
    { "name": "target", "requires": ["Cargo.toml", "pom.xml"] }
  ],
  "files": ["*.pyc", "*.tsbuildinfo"],
  "exclude": [".git"],
  "forbiddenRoots": []
}
```

### Schema

- **`directories`** — directory rules. Three forms:
  - Plain name (`"node_modules"`) — exact directory-name match anywhere in the tree.
  - Wildcard name (`"build-*"`) — wildcard match against the directory leaf name.
  - Path with `/` or `\` (`".idea/shelf"`, `"vendored/**"`) — path match relative to the target. `**` segment matches any depth.
  - Object form `{ name, requires }` — only fires when a sibling file in the matched directory's parent matches at least one `requires` glob. Used to disambiguate generic names like `bin`/`obj`/`target`.
- **`files`** — wildcard glob patterns matched against file names anywhere in the tree.
- **`exclude`** — same grammar as `directories`. Checked first; an excluded path is never deleted.
- **`forbiddenRoots`** — extra directories the cleaner refuses to operate on, on top of drive roots, `$env:USERPROFILE`, and `Documents`.

## Usage

```powershell
# Show what would be removed (read-only)
Get-ProjectCleanReport -Path C:\repos\myproject -IncludeSize

# Actual cleanup with one bulk confirmation
Invoke-ProjectClean -Path C:\repos\myproject

# Skip the prompt
Invoke-ProjectClean -Path C:\repos\myproject -Confirm:$false

# Dry-run via standard -WhatIf
Invoke-ProjectClean -Path C:\repos\myproject -WhatIf -Verbose

# Pipe-friendly object output
Get-ProjectCleanReport -Path . -PassThru | Where-Object Size -gt 100MB
```

### Parameters

`Invoke-ProjectClean`:

| Parameter | Description |
|---|---|
| `-Path` | Root to clean. Defaults to current location. |
| `-IncludeSize` | Compute total bytes and file count per match. Adds one recursive enumeration per matched directory. Off by default for speed. |
| `-Quiet` | Suppress per-item verbose output. |
| `-PassThru` | Emit one `ProjectClean.Item` per processed candidate. |
| `-Acknowledge` | Required when the active config does not have `.git` in `exclude`. |
| `-WhatIf` / `-Confirm` | Standard PowerShell. `ConfirmImpact='High'`. |

`Get-ProjectCleanReport`: same minus `-Acknowledge` and `-Quiet`.

## Behavior

- **Pruning.** When a directory matches a rule, it is removed without enumerating its children. A 200k-file `node_modules` is one delete, not 200k.
- **Bulk confirmation.** One `ShouldContinue` showing totals before the loop. No per-item prompts.
- **Reparse points.** Junctions and symbolic links are removed as links (`[IO.Directory]::Delete($path, $false)`); the target is never followed.
- **Forbidden roots.** Refuses to walk drive roots, `$env:USERPROFILE`, `Documents`, or anything in `forbiddenRoots`.
- **`.git` guard.** Refuses to run if `.git` is not in `exclude`, unless `-Acknowledge` is passed.
- **Per-item failures** (locked file, permission denied) log a warning, count, and continue. Non-zero exit on any failure.
- **Idempotent.** Second run is a no-op.

## Output objects

`-PassThru` and `Get-ProjectCleanReport -PassThru` emit `[ProjectClean.Item]`:

| Property | |
|---|---|
| `Path` | Absolute path |
| `Kind` | `Directory` or `File` |
| `Rule` | Pattern that matched |
| `Size` | Bytes (with `-IncludeSize`, else `$null`) |
| `FileCount` | File count under the item (with `-IncludeSize`, else `$null`) |
| `Action` | `Removed`, `WouldRemove`, `Failed` |

## Requirements

- PowerShell 7.4+
- `Shared` module (in this repo) — provides `Get-ModuleConfig`
- `powershell-yaml` is **not** used; config is JSON validated against `config.schema.json`
