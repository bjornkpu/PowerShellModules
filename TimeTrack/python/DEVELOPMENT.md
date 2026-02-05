# Development Setup

## Using Recorded Fixtures (No API Quota)

For development without consuming API quota:

1. **Record fixtures once** (uses ~3 API calls):

   ```bash
   # Ensure config has "backend": "toggl"
   uv run python record_fixtures.py
   ```

2. **Switch to fixtures mode**:
   Edit `~\.config\TimeTrack\config.json`:

   ```json
   {
     "source": {
       "backend": "fixtures"
     }
   }
   ```

3. **Develop freely** - all commands now use saved responses:

   ```bash
   uv run timetrack report all
   uv run timetrack lunch dry
   # etc - no API calls!
   ```

4. **Switch back to real API** when needed:

   ```json
   {
     "source": {
       "backend": "toggl",
       "apiToken": "...",
       "workspaceId": 123
     }
   }
   ```

## Backend Options

- `toggl` - Real Toggl API (uses quota: 30 req/hour)
- `fixtures` - Recorded responses (no quota, uses `tests/fixtures/*.json`)
- `mock` - Synthetic test data (no quota, fake Mon-Fri schedule)

## Fixtures Contents

Recorded in `tests/fixtures/`:

- `toggl_entries.json` - Time entries for current week
- `toggl_projects.json` - Projects used in those entries
- `toggl_week_response.json` - Raw API response (from initial capture)

Update fixtures by running `record_fixtures.py` again.
