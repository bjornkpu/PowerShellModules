"""Mock provider for testing without API calls."""

from datetime import datetime, timedelta, timezone
from typing import Any

from .base import TimeEntry, TimeTrackingProvider


class MockProvider(TimeTrackingProvider):
    """Mock time tracking provider with static test data."""

    def __init__(self, workspace_id: int = 1):
        """Initialize mock provider."""
        self.workspace_id = workspace_id
        self._projects = {
            1: {"id": 1, "name": "Mimir Drift"},
            2: {"id": 2, "name": "Mimir Norne"},
            3: {"id": 3, "name": "Mimir Utvikling"},
            4: {"id": 4, "name": "Work Crayon"},
            5: {"id": 5, "name": "Lunsj"},
        }
        self._next_entry_id = 1000

    def get_entries(
        self,
        start_date: datetime,
        end_date: datetime,
    ) -> list[TimeEntry]:
        """Get mock time entries for date range."""
        entries = []
        current = start_date.replace(hour=0, minute=0, second=0, microsecond=0)

        while current < end_date:
            if current.weekday() < 5:  # Monday-Friday
                project_id = [1, 2, 3, 1, 4][current.weekday()]
                project_name = str(self._projects[project_id]["name"])

                # Morning work (7:00-11:00)
                entries.append(
                    TimeEntry(
                        id=self._next_entry_id,
                        start=current.replace(hour=7, tzinfo=timezone.utc),
                        stop=current.replace(hour=11, tzinfo=timezone.utc),
                        duration=14400,
                        description="Morning work",
                        project=project_name,
                        project_id=project_id,
                        workspace_id=self.workspace_id,
                        tags=["work"],
                    )
                )
                self._next_entry_id += 1

                # Lunch (11:00-11:30)
                entries.append(
                    TimeEntry(
                        id=self._next_entry_id,
                        start=current.replace(hour=11, tzinfo=timezone.utc),
                        stop=current.replace(hour=11, minute=30, tzinfo=timezone.utc),
                        duration=1800,
                        description="Lunch",
                        project="Lunsj",
                        project_id=5,
                        workspace_id=self.workspace_id,
                        tags=[],
                    )
                )
                self._next_entry_id += 1

                # Afternoon work (11:30-15:00)
                entries.append(
                    TimeEntry(
                        id=self._next_entry_id,
                        start=current.replace(hour=11, minute=30, tzinfo=timezone.utc),
                        stop=current.replace(hour=15, tzinfo=timezone.utc),
                        duration=12600,
                        description="Afternoon work",
                        project=project_name,
                        project_id=project_id,
                        workspace_id=self.workspace_id,
                        tags=["work"],
                    )
                )
                self._next_entry_id += 1

            current += timedelta(days=1)

        return entries

    def add_entry(
        self,
        start: datetime,
        stop: datetime,
        description: str,
        project_id: int | None = None,
        workspace_id: int | None = None,
        tags: list[str] | None = None,
    ) -> TimeEntry:
        """Create a mock time entry."""
        entry_id = self._next_entry_id
        self._next_entry_id += 1
        duration = int((stop - start).total_seconds())
        project_name = (
            str(self._projects[project_id]["name"])
            if project_id and project_id in self._projects
            else None
        )

        return TimeEntry(
            id=entry_id,
            start=start,
            stop=stop,
            duration=duration,
            description=description,
            project=project_name,
            project_id=project_id,
            workspace_id=workspace_id or self.workspace_id,
            tags=tags or [],
        )

    def update_entry(self, entry_id: str | int, **kwargs: Any) -> TimeEntry:
        """Mock update."""
        return TimeEntry(
            id=entry_id,
            start=datetime.now(timezone.utc),
            stop=datetime.now(timezone.utc) + timedelta(hours=1),
            duration=3600,
            description=kwargs.get("description", "Updated"),
            project=None,
            project_id=kwargs.get("project_id"),
            workspace_id=self.workspace_id,
            tags=kwargs.get("tags", []),
        )

    def delete_entry(self, entry_id: str | int) -> None:
        """Mock delete."""
        pass

    def get_project_id(self, project_name: str) -> int | None:
        """Get project ID by name."""
        for project_id, project in self._projects.items():
            if project["name"] == project_name:
                return project_id
        return None

    def populate_project_names(self, entries: list[TimeEntry]) -> None:
        """Populate project names (already done in mock)."""
        for entry in entries:
            if entry.project_id and not entry.project:
                entry.project = self._projects.get(entry.project_id, {}).get("name")
