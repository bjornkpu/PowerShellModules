# Test Fixtures

This directory contains saved API responses for offline development and testing.

## Generating Fixtures

To capture real API responses (requires valid Toggl API token in config):

```bash
# From the python directory
uv run python record_fixtures.py
```

**Note:** This uses approximately 3 API requests.

## Files

- `toggl_week_response.json` - Raw API response for time entries (if needed for debugging)
- `toggl_entries.json` - Processed time entries for a sample week
- `toggl_projects.json` - Project definitions used in those entries

## Using Fixtures

Configure your `~/.config/TimeTrack/config.json` to use fixtures:

```json
{
  "source": {
    "backend": "fixtures"
  }
}
```

This allows running all commands without consuming API quota:

```bash
uv run timetrack report all
uv run timetrack set-lunch
uv run timetrack remaining
```

## Updating Fixtures

Re-run `record_fixtures.py` whenever you need fresh data or if your project structure changes.

## Privacy

⚠️ **Important:** Fixture files may contain sensitive information (project names, descriptions, client names). These files are gitignored by default to prevent accidental commits.
