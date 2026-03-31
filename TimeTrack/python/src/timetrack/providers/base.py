"""Base provider protocol for time tracking backends."""

from datetime import datetime
from typing import Any, Protocol


class TimeEntry:
    """Time entry data model."""

    def __init__(
        self,
        id: str | int,
        start: datetime,
        stop: datetime | None,
        duration: int,  # Duration in seconds
        description: str,
        project: str | None,
        project_id: str | int | None,
        workspace_id: str | int,
        tags: list[str] | None = None,
        billable: bool = False,
    ):
        self.id = id
        self.start = start
        self.stop = stop
        self.duration = duration
        self.description = description
        self.project = project
        self.project_id = project_id
        self.workspace_id = workspace_id
        self.tags = tags or []
        self.billable = billable

    @property
    def duration_hours(self) -> float:
        """Get duration in hours."""
        return self.duration / 3600

    def __repr__(self) -> str:
        return (
            f"TimeEntry(id={self.id}, project={self.project}, "
            f"start={self.start.isoformat()}, duration={self.duration_hours:.2f}h)"
        )


class TimeTrackingProvider(Protocol):
    """Protocol defining interface for time tracking backends."""

    def get_entries(
        self,
        start_date: datetime,
        end_date: datetime,
    ) -> list[TimeEntry]:
        """Get time entries for date range.

        Args:
            start_date: Start date (inclusive)
            end_date: End date (inclusive)

        Returns:
            List of time entries
        """
        ...

    def add_entry(
        self,
        start: datetime,
        stop: datetime,
        description: str,
        project_id: int | None = None,
        workspace_id: int | None = None,
        tags: list[str] | None = None,
    ) -> TimeEntry:
        """Create a new time entry.

        Args:
            start: Start time
            stop: Stop time
            description: Entry description
            project_id: Optional project ID
            workspace_id: Optional workspace ID
            tags: Optional tags

        Returns:
            Created time entry
        """
        ...

    def update_entry(self, entry_id: str | int, **kwargs: Any) -> TimeEntry:
        """Update an existing time entry.

        Args:
            entry_id: Entry ID to update
            **kwargs: Fields to update

        Returns:
            Updated time entry
        """
        ...

    def delete_entry(self, entry_id: str | int) -> None:
        """Delete a time entry.

        Args:
            entry_id: Entry ID to delete
        """
        ...

    def get_project_id(self, project_name: str) -> str | int | None:
        """Get project ID by name.

        Args:
            project_name: Project name to look up

        Returns:
            Project ID or None if not found
        """
        ...

    def populate_project_names(self, entries: list[TimeEntry]) -> None:
        """Populate project names for a list of time entries in-place.

        This allows efficient loading of project names for multiple entries
        with a single API call (if not already cached).

        Args:
            entries: List of time entries to populate project names for
        """
        ...
