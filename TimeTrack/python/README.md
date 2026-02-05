# TimeTrack

Time tracking automation with pluggable backends.

## Installation

```bash
uv sync
```

## Configuration

Edit `~\.config\TimeTrack\config.json` and set:

### Backend Options

- `"backend": "toggl"` - Use real Toggl API (uses quota)
- `"backend": "fixtures"` - Use recorded API responses (no quota, for development)
- `"backend": "mock"` - Use fake test data

### Recording Fixtures

To capture real API responses for offline development:

```bash
# Set backend to "toggl" in config
uv run python record_fixtures.py
```

This saves responses to `tests/fixtures/` for use with `"backend": "fixtures"`.

> **Note:** This command uses approximately 3 API requests.

## Development

### Code Quality Tools

This project uses [Astral](https://astral.sh/)'s modern Python tooling:

- **Ruff**: Fast linter and formatter
- **ty**: Extremely fast type checker

#### Run Linter

```bash
uv run ruff check . --fix
```

#### Run Type Checker

```bash
uv run ty check .
```

#### Format Code

```bash
uv run ruff format .
```

### Testing

```bash
uv run pytest
```
