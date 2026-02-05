# TimeTrack

Time tracking automation module with pluggable backends (Toggl Track) and multi-system reporting for consultants managing multiple timesheet systems.

## Features

- **Pluggable Backends**: Currently supports Toggl Track API v9, extensible to other time tracking services
- **Automatic Lunch Breaks**: Detects work entries overlapping 11:00-11:30 and automatically inserts 30-minute lunch breaks
- **Multi-System Reporting**: Generate customized weekly reports for different timesheet systems:
  - **TimeReg**: Aggregated daily hours (single row per day)
  - **xledger**: Separate project rows per day
  - **Enova**: Separate project rows per day
- **Work Hours Tracking**: Calculate remaining hours for the month, accounting for Norwegian holidays and vacation days
- **Config-Driven**: All credentials and project mappings in `~/.config/TimeTrack/config.json`

## Installation

```powershell
# Module will be published to PowerShell Gallery
Install-Module TimeTrack -Scope CurrentUser

# Or clone and import manually
Import-Module .\TimeTrack
```

## Configuration

On first use, the module will prompt for configuration. Alternatively, create `~/.config/TimeTrack/config.json`:

```json
{
  "backend": "toggl",
  "toggl": {
    "apiToken": "your-toggl-api-token-here",
    "workspaceId": 1234567
  },
  "lunchProject": "PersonalClient > Lunch",
  "reportingRules": {
    "timereg": {
      "rounding": 0.5,
      "aggregate": true
    },
    "xledger": {
      "rounding": 0.5
    },
    "enova": {
      "rounding": 0.5
    }
  },
  "projectMappings": [
    {
      "togglProject": "PersonalClient > Lunch",
      "client": "PersonalClient"
    },
    {
      "togglProject": "CompanyA > Operations",
      "client": "CompanyA",
      "timereg": "Work CompanyA",
      "xledger": "CMPA-OPS-001",
      "enova": "OPERATIONS"
    },
    {
      "togglProject": "CompanyA > Development",
      "client": "CompanyA",
      "timereg": "Work CompanyA",
      "xledger": "CMPA-DEV-002",
      "enova": "DEVELOPMENT"
    }
  ]
}
```

Get your Toggl API token from: <https://track.toggl.com/profile>

## Usage

### Add Lunch Breaks

Automatically insert 30-minute lunch breaks at 11:00 for the current week:

```powershell
# Current week
tt set-lunch

# Specific week (by week number)
tt set-lunch --week 4

# Specific week (by date)
tt set-lunch --week 2026-01-27

# Preview without modifying
tt set-lunch --dry-run
```

### Generate Reports

Generate weekly timesheet reports for different systems:

```powershell
# TimeReg report (aggregated daily hours)
tt report timereg

# xledger report (separate project rows)
tt report xledger --week 4

# Enova report
tt report enova --week 2026-01-27

# All three systems
tt report all
```

### Check Remaining Hours

Calculate work hours for the month:

```powershell
# Current month
tt remaining

# Specific month
tt remaining --month 1
```

Shows:

- Expected hours (7.5h × workdays - Norwegian holidays - vacation days)
- Actual hours tracked
- Difference (+/- hours)
- Remaining workdays and needed hours per day

## Project Mapping

The module maps Toggl projects to different timesheet systems through the `projectMappings` config:

- **togglProject**: Exact Toggl project name
- **client**: Client name (entries with `client: "PersonalClient"` are excluded from reports)
- **timereg**: Project name for TimeReg (aggregated across all projects)
- **xledger**: Project code for xledger
- **enova**: Project code for Enova

Projects without a mapping for a specific system are silently excluded from that system's report.

## Architecture

This is a PowerShell-Python hybrid module following the [powershell-python-hybrid.md](.github/instructions/powershell-python-hybrid.md) pattern:

- **PowerShell Layer**: Module loading, config management, command invocation (alias: `tt`)
- **Python Layer**: Business logic, API clients, date calculations, report generation
- **Dependencies**: Python package managed with `uv`, no global Python packages required

## Development

```powershell
# Enable live reload
$env:PS_DEV_MODE = $true
Import-Module .\TimeTrack -Force

# Python development
cd TimeTrack/python
uv sync
uv run pytest
uv run ruff check .

# Run CLI directly
uv run timetrack --help
```

## Requirements

- PowerShell 5.1+
- Python 3.10+ (managed by uv)
- uv package manager
- Toggl Track account with API access

## License

See [LICENSE](../LICENSE)
