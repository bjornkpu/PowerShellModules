"""Enhanced mock provider that can record and replay API responses."""

import json
from datetime import datetime
from pathlib import Path
from typing import Any

from .base import TimeEntry, TimeTrackingProvider


class RecordingMockProvider(TimeTrackingProvider):
    """Mock provider that loads from saved JSON responses."""

    def __init__(self, fixtures_dir: str | None = None):
        """Initialize with path to fixtures directory."""
        if fixtures_dir:
            self.fixtures_dir = Path(fixtures_dir)
        else:
            # Default to tests/fixtures
            self.fixtures_dir = Path(__file__).parent.parent.parent / "tests" / "fixtures"

        self.fixtures_dir.mkdir(parents=True, exist_ok=True)

        # Load responses
        self._entries_response = self._load_fixture("toggl_entries.json")
        self._projects_response = self._load_fixture("toggl_projects.json")

    def _load_fixture(self, filename: str) -> list[dict[str, Any]]:
        """Load fixture file."""
        fixture_file = self.fixtures_dir / filename
        if not fixture_file.exists():
            return []

        with open(fixture_file, encoding="utf-8") as f:
            return json.load(f)

    def get_entries(
        self,
        start_date: datetime,
        end_date: datetime,
    ) -> list[TimeEntry]:
        """Get time entries from saved fixture."""
        entries = []

        for entry_data in self._entries_response:
            start = datetime.fromisoformat(entry_data["start"].replace("Z", "+00:00"))
            stop_str = entry_data.get("stop")
            stop = datetime.fromisoformat(stop_str.replace("Z", "+00:00")) if stop_str else None

            # Filter by date range
            if start < start_date or start >= end_date:
                continue

            entry = TimeEntry(
                id=entry_data["id"],
                start=start,
                stop=stop,
                duration=entry_data["duration"],
                description=entry_data.get("description", ""),
                project=None,  # Will be populated later
                project_id=entry_data.get("project_id"),
                workspace_id=entry_data.get("workspace_id", 1),
                tags=entry_data.get("tags", []),
            )
            entries.append(entry)

        return entries

    def populate_project_names(self, entries: list[TimeEntry]) -> None:
        """Populate project names from fixture."""
        project_map = {p["id"]: p["name"] for p in self._projects_response}

        for entry in entries:
            if entry.project_id:
                entry.project = project_map.get(entry.project_id)

    def add_entry(
        self,
        start: datetime,
        stop: datetime,
        description: str,
        project_id: int | None = None,
        workspace_id: int | None = None,
        tags: list[str] | None = None,
    ) -> TimeEntry:
        """Not implemented for recorded fixtures."""
        raise NotImplementedError("Cannot add entries to recorded fixtures")

    def update_entry(self, entry_id: str | int, **kwargs: Any) -> TimeEntry:
        """Not implemented for recorded fixtures."""
        raise NotImplementedError("Cannot update entries in recorded fixtures")
