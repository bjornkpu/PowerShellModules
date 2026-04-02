"""Toggl Track API provider implementation."""

import base64
import time
from datetime import datetime, timezone
from typing import Any
from zoneinfo import ZoneInfo

import httpx

from .base import TimeEntry, TimeTrackingProvider


class TogglProvider(TimeTrackingProvider):
    """Toggl Track API v9 provider."""

    BASE_URL = "https://api.track.toggl.com/api/v9"

    def __init__(self, api_token: str, workspace_id: int):
        """Initialize Toggl provider.

        Args:
            api_token: Toggl API token
            workspace_id: Default workspace ID
        """
        self.api_token = api_token
        self.workspace_id = workspace_id

        # Create auth header (basic auth with api_token:api_token)
        auth_string = f"{api_token}:api_token"
        auth_bytes = auth_string.encode("ascii")
        auth_b64 = base64.b64encode(auth_bytes).decode("ascii")

        self.headers = {
            "Authorization": f"Basic {auth_b64}",
            "Content-Type": "application/json",
        }

        self.client = httpx.Client(headers=self.headers, timeout=30.0)
        self._projects_cache: dict[int, dict[str, Any]] | None = None
        self._quota_remaining: int | None = None
        self._quota_resets_in: int | None = None

    def _handle_response(self, response: httpx.Response) -> httpx.Response:
        """Handle response and track quota headers.

        Args:
            response: HTTP response from Toggl API

        Returns:
            The response if successful

        Raises:
            httpx.HTTPStatusError: For error responses
        """
        # Track quota headers
        self._quota_remaining = response.headers.get("X-Toggl-Quota-Remaining")
        if self._quota_remaining is not None:
            self._quota_remaining = int(self._quota_remaining)

        self._quota_resets_in = response.headers.get("X-Toggl-Quota-Resets-In")
        if self._quota_resets_in is not None:
            self._quota_resets_in = int(self._quota_resets_in)

        # Handle rate limiting
        if response.status_code == 429:
            # Rate limit hit - wait 1 second and retry once
            time.sleep(1)
            raise httpx.HTTPStatusError(
                "Rate limit exceeded (429). Please slow down requests.",
                request=response.request,
                response=response,
            )
        elif response.status_code == 402:
            # Quota exceeded
            wait_time = self._quota_resets_in or 60
            if wait_time > 59:
                wait_minutes = wait_time / 60
                time_str = f"{wait_minutes:.1f} minutes"
            else:
                time_str = f"{wait_time} seconds"
            raise httpx.HTTPStatusError(
                f"API quota exceeded (402). Quota resets in {time_str}.",
                request=response.request,
                response=response,
            )

        response.raise_for_status()
        return response

    @property
    def quota_remaining(self) -> int | None:
        """Get remaining API quota from last request."""
        return self._quota_remaining

    @property
    def quota_resets_in(self) -> int | None:
        """Get seconds until quota resets from last request."""
        return self._quota_resets_in

    def _load_projects(self) -> None:
        """Load projects from workspace into cache."""
        if self._projects_cache is not None:
            return

        url = f"{self.BASE_URL}/workspaces/{self.workspace_id}/projects"
        response = self.client.get(url)
        self._handle_response(response)

        projects = response.json()
        self._projects_cache = {p["id"]: p for p in projects}

    def _get_project_name(self, project_id: int | None) -> str | None:
        """Get project name by ID."""
        if project_id is None:
            return None

        self._load_projects()

        if self._projects_cache and project_id in self._projects_cache:
            return self._projects_cache[project_id]["name"]

        return None

    def get_entries(
        self,
        start_date: datetime,
        end_date: datetime,
    ) -> list[TimeEntry]:
        """Get time entries for date range.

        Note: Uses /me/time_entries endpoint (30 req/hour limit regardless of plan).
        Only loads project names if needed (lazy loading to minimize API calls).

        Args:
            start_date: Start of date range (inclusive)
            end_date: End of date range (inclusive)

        Returns:
            List of time entries
        """
        # Ensure datetimes are timezone-aware
        # If naive, assume local timezone (Europe/Oslo) and convert to UTC
        local_tz = ZoneInfo("Europe/Oslo")

        if start_date.tzinfo is None:
            start_date = start_date.replace(tzinfo=local_tz)
        if end_date.tzinfo is None:
            end_date = end_date.replace(tzinfo=local_tz)

        # Convert to UTC for API
        start_date = start_date.astimezone(timezone.utc)
        end_date = end_date.astimezone(timezone.utc)

        # Toggl API expects ISO 8601 format with timezone
        start_iso = start_date.isoformat()
        end_iso = end_date.isoformat()

        # Use /me/time_entries endpoint (workspace endpoint doesn't support GET)
        url = f"{self.BASE_URL}/me/time_entries"
        params = {
            "start_date": start_iso,
            "end_date": end_iso,
        }

        response = self.client.get(url, params=params)
        self._handle_response(response)

        entries_data = response.json()
        entries = []

        for entry_data in entries_data:
            # Parse timestamps
            start = datetime.fromisoformat(entry_data["start"].replace("Z", "+00:00"))
            stop_str = entry_data.get("stop")
            stop = datetime.fromisoformat(stop_str.replace("Z", "+00:00")) if stop_str else None

            # Don't load project names unless we need them
            # This saves an API call per get_entries call
            project_id = entry_data.get("project_id")

            entry = TimeEntry(
                id=entry_data["id"],
                start=start,
                stop=stop,
                duration=entry_data["duration"],
                description=entry_data.get("description", ""),
                project=None,  # Lazy load project names only when needed
                project_id=project_id,
                workspace_id=entry_data["workspace_id"],
                tags=entry_data.get("tags", []),
            )
            entries.append(entry)

        return entries

    def add_entry(
        self,
        start: datetime,
        stop: datetime,
        description: str,
        project_id: int | None = None,
        workspace_id: int | None = None,
        tags: list[str] | None = None,
        billable: bool = False,
    ) -> TimeEntry:
        """Create a new time entry.

        Args:
            start: Start time
            stop: Stop time
            description: Entry description
            project_id: Optional project ID
            workspace_id: Optional workspace ID (defaults to provider's workspace)
            tags: Optional list of tags

        Returns:
            Created time entry
        """
        workspace = workspace_id or self.workspace_id

        # Ensure datetimes are timezone-aware
        if start.tzinfo is None:
            start = start.replace(tzinfo=timezone.utc)
        if stop.tzinfo is None:
            stop = stop.replace(tzinfo=timezone.utc)

        # Calculate duration in seconds
        duration = int((stop - start).total_seconds())

        payload = {
            "start": start.isoformat(),
            "stop": stop.isoformat(),
            "duration": duration,
            "description": description,
            "workspace_id": workspace,
            "created_with": "timetrack",
        }

        if project_id is not None:
            payload["project_id"] = project_id

        if tags:
            payload["tags"] = tags

        url = f"{self.BASE_URL}/workspaces/{workspace}/time_entries"
        response = self.client.post(url, json=payload)
        self._handle_response(response)

        entry_data = response.json()

        # Parse response
        stop_str = entry_data.get("stop")
        return TimeEntry(
            id=entry_data["id"],
            start=datetime.fromisoformat(entry_data["start"].replace("Z", "+00:00")),
            stop=datetime.fromisoformat(stop_str.replace("Z", "+00:00")) if stop_str else None,
            duration=entry_data["duration"],
            description=entry_data.get("description", ""),
            project=None,  # Lazy load project names
            project_id=entry_data.get("project_id"),
            workspace_id=entry_data["workspace_id"],
            tags=entry_data.get("tags", []),
        )

    def update_entry(self, entry_id: str | int, **kwargs: Any) -> TimeEntry:
        """Update an existing time entry.

        Args:
            entry_id: ID of the time entry to update
            **kwargs: Fields to update

        Returns:
            Updated time entry
        """
        url = f"{self.BASE_URL}/workspaces/{self.workspace_id}/time_entries/{entry_id}"

        response = self.client.put(url, json=kwargs)
        self._handle_response(response)

        entry_data = response.json()

        stop_str = entry_data.get("stop")
        return TimeEntry(
            id=entry_data["id"],
            start=datetime.fromisoformat(entry_data["start"].replace("Z", "+00:00")),
            stop=datetime.fromisoformat(stop_str.replace("Z", "+00:00")) if stop_str else None,
            duration=entry_data["duration"],
            description=entry_data.get("description", ""),
            project=None,  # Lazy load project names
            project_id=entry_data.get("project_id"),
            workspace_id=entry_data["workspace_id"],
            tags=entry_data.get("tags", []),
        )

    def delete_entry(self, entry_id: str | int) -> None:
        """Delete a time entry.

        Args:
            entry_id: ID of the time entry to delete
        """
        url = f"{self.BASE_URL}/workspaces/{self.workspace_id}/time_entries/{entry_id}"

        response = self.client.delete(url)
        self._handle_response(response)

    def get_project_id(self, project_name: str) -> int | None:
        """Get project ID by name.

        Args:
            project_name: Name of the project

        Returns:
            Project ID if found, None otherwise
        """
        self._load_projects()

        if not self._projects_cache:
            return None

        for project_id, project in self._projects_cache.items():
            if project["name"] == project_name:
                return project_id

        return None

    def populate_project_names(self, entries: list[TimeEntry]) -> None:
        """Populate project names for a list of time entries in-place.

        This is more efficient than loading projects for each entry individually.
        Only makes one API call to load all projects if not already cached.

        Args:
            entries: List of time entries to populate project names for
        """
        self._load_projects()

        for entry in entries:
            if entry.project_id is not None and self._projects_cache:
                entry.project = self._projects_cache.get(entry.project_id, {}).get("name")

    def __del__(self):
        """Close HTTP client on cleanup."""
        if hasattr(self, "client"):
            self.client.close()
