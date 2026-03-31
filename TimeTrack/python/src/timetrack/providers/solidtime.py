"""Solidtime API provider implementation."""

from datetime import datetime, timezone
from typing import Any
from zoneinfo import ZoneInfo

import httpx

from .base import TimeEntry, TimeTrackingProvider


def get_solidtime_memberships(base_url: str, api_key: str) -> list[dict[str, str]]:
    """Get organization memberships for the authenticated user.

    Use this to discover the organization ID and member ID needed for config.

    Args:
        base_url: Solidtime instance base URL (e.g. https://app.solidtime.io)
        api_key: Solidtime API key

    Returns:
        List of {"organizationId": str, "organizationName": str, "memberId": str} dicts
    """
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Accept": "application/json",
    }
    with httpx.Client(headers=headers, timeout=30.0) as client:
        response = client.get(f"{base_url.rstrip('/')}/api/v1/users/me/memberships")
        response.raise_for_status()
        data = response.json()

    memberships = data.get("data", data)
    return [
        {
            "organizationId": m["organization"]["id"],
            "organizationName": m["organization"]["name"],
            "memberId": m["id"],
        }
        for m in memberships
    ]


class SolidtimeProvider(TimeTrackingProvider):
    """Solidtime API provider."""

    def __init__(self, base_url: str, api_key: str, organization_id: str, member_id: str):
        """Initialize Solidtime provider.

        Args:
            base_url: Solidtime instance base URL
            api_key: Solidtime API key
            organization_id: Organization UUID
            member_id: Member UUID (from /users/me/memberships)
        """
        self.base_url = f"{base_url.rstrip('/')}/api/v1"
        self.organization_id = organization_id
        self.member_id = member_id

        self.client = httpx.Client(
            headers={
                "Authorization": f"Bearer {api_key}",
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
            timeout=30.0,
        )
        self._projects_cache: dict[str, dict[str, Any]] | None = None

    def _load_projects(self) -> None:
        """Load all projects from organization into cache."""
        if self._projects_cache is not None:
            return

        self._projects_cache = {}
        page = 1
        while True:
            url = f"{self.base_url}/organizations/{self.organization_id}/projects"
            response = self.client.get(url, params={"page": page})
            response.raise_for_status()
            body = response.json()

            for p in body["data"]:
                self._projects_cache[p["id"]] = p

            meta = body.get("meta", {})
            last_page = meta.get("last_page", meta.get("current_page", 1))
            if page >= last_page:
                break
            page += 1

    def get_entries(
        self,
        start_date: datetime,
        end_date: datetime,
    ) -> list[TimeEntry]:
        """Get time entries for date range.

        Args:
            start_date: Start of date range (inclusive)
            end_date: End of date range (inclusive)

        Returns:
            List of time entries
        """
        local_tz = ZoneInfo("Europe/Oslo")

        if start_date.tzinfo is None:
            start_date = start_date.replace(tzinfo=local_tz)
        if end_date.tzinfo is None:
            end_date = end_date.replace(tzinfo=local_tz)

        start_date = start_date.astimezone(timezone.utc)
        end_date = end_date.astimezone(timezone.utc)

        url = f"{self.base_url}/organizations/{self.organization_id}/time-entries"
        entries: list[TimeEntry] = []
        offset = 0
        limit = 500

        while True:
            params = {
                "start": start_date.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "end": end_date.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "limit": limit,
                "offset": offset,
            }
            response = self.client.get(url, params=params)
            response.raise_for_status()
            body = response.json()

            entries_data = body.get("data", body)
            if not entries_data:
                break

            for e in entries_data:
                entries.append(self._parse_entry(e))

            if len(entries_data) < limit:
                break
            offset += limit

        return entries

    def _parse_entry(self, data: dict[str, Any]) -> TimeEntry:
        """Parse a TimeEntryResource into a TimeEntry."""
        start = datetime.fromisoformat(data["start"].replace("Z", "+00:00"))
        end_str = data.get("end")
        stop = datetime.fromisoformat(end_str.replace("Z", "+00:00")) if end_str else None

        duration = data.get("duration")
        if duration is None and stop is not None:
            duration = int((stop - start).total_seconds())
        elif duration is None:
            duration = 0

        return TimeEntry(
            id=data["id"],
            start=start,
            stop=stop,
            duration=duration,
            description=data.get("description") or "",
            project=None,
            project_id=data.get("project_id"),
            workspace_id=data.get("organization_id", self.organization_id),
            tags=data.get("tags", []),
            billable=data.get("billable", False),
        )

    def add_entry(
        self,
        start: datetime,
        stop: datetime,
        description: str,
        project_id: int | None = None,
        workspace_id: int | None = None,
        tags: list[str] | None = None,
    ) -> TimeEntry:
        if start.tzinfo is None:
            start = start.replace(tzinfo=timezone.utc)
        if stop.tzinfo is None:
            stop = stop.replace(tzinfo=timezone.utc)

        payload: dict[str, Any] = {
            "member_id": self.member_id,
            "start": start.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "end": stop.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "billable": False,
            "description": description,
        }

        if project_id is not None:
            payload["project_id"] = str(project_id)
        if tags:
            payload["tags"] = tags

        url = f"{self.base_url}/organizations/{self.organization_id}/time-entries"
        response = self.client.post(url, json=payload)
        response.raise_for_status()
        return self._parse_entry(response.json()["data"])

    def update_entry(self, entry_id: str | int, **kwargs: Any) -> TimeEntry:
        payload: dict[str, Any] = {}

        if "start" in kwargs:
            s = kwargs["start"]
            if isinstance(s, datetime):
                if s.tzinfo is None:
                    s = s.replace(tzinfo=timezone.utc)
                payload["start"] = s.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            else:
                payload["start"] = s

        if "stop" in kwargs or "end" in kwargs:
            e = kwargs.get("stop") or kwargs.get("end")
            if isinstance(e, datetime):
                if e.tzinfo is None:
                    e = e.replace(tzinfo=timezone.utc)
                payload["end"] = e.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            else:
                payload["end"] = e

        if "description" in kwargs:
            payload["description"] = kwargs["description"]
        if "project_id" in kwargs:
            pid = kwargs["project_id"]
            payload["project_id"] = str(pid) if pid is not None else None
        if "billable" in kwargs:
            payload["billable"] = kwargs["billable"]
        if "tags" in kwargs:
            payload["tags"] = kwargs["tags"]

        url = f"{self.base_url}/organizations/{self.organization_id}/time-entries/{entry_id}"
        response = self.client.put(url, json=payload)
        response.raise_for_status()
        return self._parse_entry(response.json()["data"])

    def delete_entry(self, entry_id: str | int) -> None:
        url = f"{self.base_url}/organizations/{self.organization_id}/time-entries/{entry_id}"
        response = self.client.delete(url)
        response.raise_for_status()

    def get_project_id(self, project_name: str) -> str | None:
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
        """Populate project names for entries in-place.

        Args:
            entries: List of time entries to populate project names for
        """
        self._load_projects()

        for entry in entries:
            if entry.project_id is not None and self._projects_cache:
                entry.project = self._projects_cache.get(str(entry.project_id), {}).get("name")

    def __del__(self):
        """Close HTTP client on cleanup."""
        if hasattr(self, "client"):
            self.client.close()
