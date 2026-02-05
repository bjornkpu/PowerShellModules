# TestWatch

Intelligent wrapper for pytest-watch with fuzzy search, auto-detection of Poetry/UV, and source path derivation.

## Installation

```powershell
Import-Module TestWatch
```

## Usage

```powershell
# Watch all tests
tw

# Fuzzy search for test file
tw key_vault_unit

# Watch entire directory
tw connectors/

# Fuzzy search in specific directory
tw connectors/key_vault
```

## Features

- Auto-detects Poetry or UV from lock files
- Fuzzy matching for test files (no need to type `test_` prefix)
- Derives source paths from pyproject.toml project name
- Tab completion for test files and directories
- Wraps pytest-watch for file watching
