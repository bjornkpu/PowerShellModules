# AGENTS.md — TimeTrack Module

## Overview

PowerShell-Python hybrid module for time tracking automation. PowerShell handles
invocation/config/secrets; Python handles all business logic via a Typer CLI.
Package manager is **uv** (Astral). Python 3.13 (minimum 3.10).

## Build & Run Commands

All Python commands run from `TimeTrack/python/`.

```bash
# Install/sync dependencies
uv sync

# Run the CLI
uv run timetrack --help
uv run timetrack report --system timereg
uv run timetrack set-lunch

# From PowerShell (module loaded)
Invoke-TimeTrack report --system timereg
tt report --system timereg          # alias
```

## Lint / Format / Type-Check

```bash
uv run ruff check . --fix     # Lint (auto-fix enabled)
uv run ruff format .           # Format
uv run ty check .              # Type check (Astral ty)
```

## Test Commands

```bash
uv run pytest                  # Run all tests
uv run pytest tests/test_report_timezone.py                    # Single file
uv run pytest tests/test_report_timezone.py::test_timezone_conversion  # Single test
uv run pytest -v               # Verbose output
```

Test framework: **pytest**. Test directory: `python/tests/`.
Fixtures in `tests/fixtures/` are gitignored (may contain project names).
Tests use `pytest.skip()` when fixture files are absent.

No Pester tests exist for the PowerShell layer.

## Project Structure

```
TimeTrack/
├── TimeTrack.psd1                  # PS module manifest (version auto-managed)
├── TimeTrack.psm1                  # PS module loader
├── Public/Invoke-TimeTrack.ps1     # Single exported function (alias: tt)
├── config.example.json             # Config template with <placeholder> markers
├── config.schema.json              # JSON Schema draft-07
└── python/
    ├── pyproject.toml              # Build config, deps, ruff/pytest settings
    ├── src/timetrack/
    │   ├── cli.py                  # Typer CLI entry (3 commands)
    │   ├── core.py                 # Business logic (lunch insertion)
    │   ├── config.py               # Config loading/validation
    │   ├── utils.py                # Date/time utilities
    │   ├── providers/              # Backend interface + implementations
    │   │   ├── base.py             # Protocol + TimeEntry model
    │   │   ├── toggl.py            # Toggl Track API v9 client
    │   │   ├── mock.py             # Static test data
    │   │   └── recording_mock.py   # Fixture-based provider
    │   └── reports/                # Report generators
    │       ├── base.py             # Shared report logic
    │       ├── timereg.py          # TimeReg format
    │       ├── xledger.py          # xLedger format
    │       └── enova.py            # Enova format
    └── tests/
```

## Architecture Pattern

- **PowerShell = transport layer** — config loading, secret injection, invocation
- **Python = application layer** — all business logic, API calls, report generation
- PowerShell calls Python via `uv run timetrack <args>` inside `Push-Location`/`Pop-Location`
- Secrets injected as environment variables, cleaned up in `finally` block
- Config lives at `~/.config/TimeTrack/config.json`

## Python Code Style

### Formatting & Linting (Ruff)

- **Line length**: 100 characters
- **Target**: Python 3.10 (`py310`)
- **Auto-fix**: Enabled
- **Rule sets**: E (pycodestyle errors), W (warnings), F (pyflakes), I (isort),
  B (flake8-bugbear), UP (pyupgrade), C4 (flake8-comprehensions)
- **First-party imports**: `timetrack` (isort grouping)

### Type Hints

- Use modern union syntax: `str | None`, not `Optional[str]`
- Use lowercase generics: `dict[str, Any]`, `list[str]`, not `Dict`, `List`
- No `from __future__ import annotations`
- Use `typing.Protocol` for interfaces (see `providers/base.py`)

### Imports

- Standard library first, third-party second, local third (enforced by ruff I rules)
- Use relative imports within the package: `from .config import ...`
- Lazy imports in CLI handlers when appropriate (defer heavy imports)

### Naming

- **Modules/packages**: `snake_case`
- **Classes**: `PascalCase` (e.g., `TimeEntry`, `TogglProvider`)
- **Functions/methods**: `snake_case`
- **Constants**: `UPPER_SNAKE_CASE` or class-level attributes (e.g., `BASE_URL`)
- **Module exports**: Use `__all__` where applicable

### Docstrings

- Google-style with `Args:` and `Returns:` sections
- Required on public functions and classes

### Error Handling

- Use `raise SomeError("message") from e` to preserve exception chains
- Provide clear, actionable error messages
- Use `typer.Exit(1)` for CLI-level failures
- Check `os.getenv()` for required secrets with clear error on missing

## PowerShell Code Style

### Functions

- **One function per file** in `Public/`
- Use approved PowerShell verbs (`Get-Verb` to verify)
- Module-specific nouns: `Invoke-TimeTrack`, not `Invoke-Track`
- Always use `[CmdletBinding()]`
- Provide comment-based help: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`

### Config Pattern (Lazy Loading)

```powershell
if (-not $script:config) {
    $script:config = Get-ModuleConfig -ModuleName 'TimeTrack'
}
```

Never validate config on module import — it blocks terminal startup.

### Error Handling

- `try`/`catch`/`finally` around external tool calls
- `Push-Location`/`Pop-Location` in `try`/`finally`
- Check `$LASTEXITCODE` after `uv run`
- Clean up env vars in `finally` block

### Parameter Validation

- `[ValidateSet()]` for constrained values
- `[ValidateNotNullOrEmpty()]` on required strings
- Provide sensible defaults from config where possible

## Git & Commits

- **Format**: Conventional commits, title only (no body)
- **Language**: English
- **Examples**: `feat: add yaml-parser for bronze-layer`, `fix: fix error in sharepoint-connection`
- **Fixes**: Reference issue numbers: `fixes #1234`
- **Never** manually edit `ModuleVersion` in `.psd1` — Git hooks manage versioning
- **Never** commit or push without explicit user request

## Config System

- User config: `~/.config/TimeTrack/config.json`
- Schema: `config.schema.json` (JSON Schema draft-07)
- All string fields must reject `<placeholder>` patterns: `"pattern": "^(?!<).*(?<!>)$"`
- Depends on `Shared` module for `Get-ModuleConfig`

## Anti-Patterns

- Do NOT hardcode credentials, paths, or company-specific values
- Do NOT capture Python output: let it flow to console (passthrough)
- Do NOT pass secrets as CLI arguments: use env vars
- Do NOT use `python -m`: use `uv run timetrack`
- Do NOT validate config on module import
- Do NOT duplicate config logic: use `Get-ModuleConfig` from Shared

## Pull Request Style

- **Language**: Norwegian by default, English if explicitly requested
- **Format**: No emojis, simple markdown, direct language
- **Sections**: Hva (What), Hvorfor (Why), Endringer (Changes)
