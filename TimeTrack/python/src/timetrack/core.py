"""Core business logic for lunch break insertion."""

from datetime import datetime, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from .providers.base import TimeTrackingProvider
from .utils import parse_week_reference


def insert_lunch_break(
    date: datetime,
    provider: TimeTrackingProvider,
    lunch_project: str,
    lunch_start_hour: int = 11,
    lunch_start_minute: int = 0,
    lunch_duration_minutes: int = 30,
    timezone: str = "Europe/Oslo",
) -> dict[str, Any]:
    """Insert lunch break for a single day (testable function).

    Detects if lunch already exists. If not, finds entries overlapping
    11:00-11:30 and splits them to insert lunch.

    Args:
        date: Date to insert lunch (only date part used)
        provider: Time tracking provider
        lunch_project: Project name for lunch entries
        lunch_start_hour: Lunch start hour (default 11)
        lunch_start_minute: Lunch start minute (default 0)
        lunch_duration_minutes: Lunch duration in minutes (default 30)
        timezone: IANA timezone for lunch time (default 'Europe/Oslo')

    Returns:
        Dictionary with operation result:
        {
            "status": "added" | "skipped_existing" | "skipped_no_work",
            "entries_modified": int,
            "lunch_entry_id": int | None
        }
    """
    # Normalize to date only
    day_start = date.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)

    # Get entries for the day
    entries = provider.get_entries(day_start, day_end)

    # Populate project names for filtering (single API call if not cached)
    provider.populate_project_names(entries)

    # Check if lunch already exists
    lunch_project_id = provider.get_project_id(lunch_project)

    for entry in entries:
        if entry.project == lunch_project:
            return {
                "status": "skipped_existing",
                "entries_modified": 0,
                "lunch_entry_id": entry.id,
            }

    # Filter to only work entries (exclude lunch project client)
    # Get client from lunch project (before " > ")
    lunch_client = lunch_project.split(" > ")[0] if " > " in lunch_project else lunch_project
    work_entries = [e for e in entries if not (e.project and e.project.startswith(lunch_client))]

    if not work_entries:
        return {
            "status": "skipped_no_work",
            "entries_modified": 0,
            "lunch_entry_id": None,
        }

    # Define lunch time window in the configured timezone
    lunch_start_naive = day_start.replace(hour=lunch_start_hour, minute=lunch_start_minute)
    local_tz = ZoneInfo(timezone)
    lunch_start = lunch_start_naive.replace(tzinfo=local_tz)

    lunch_end = lunch_start + timedelta(minutes=lunch_duration_minutes)

    # Get current time in the same timezone
    now = datetime.now(lunch_start.tzinfo)

    # Find entries overlapping lunch window or running entries past lunch time
    overlapping = []
    running_entry = None

    for entry in work_entries:
        # Handle currently running entries
        if entry.stop is None:
            # If it's past lunch time and entry started before lunch, we need to split it
            if now >= lunch_end and entry.start < lunch_start:
                running_entry = entry
            continue

        # Check overlap for completed entries
        if entry.start < lunch_end and entry.stop > lunch_start:
            overlapping.append(entry)

    # Handle running entry that needs lunch inserted
    if running_entry:
        # Stop the current entry at lunch start
        provider.update_entry(
            running_entry.id,
            stop=lunch_start.isoformat(),
        )

        # Add lunch entry
        lunch_entry = provider.add_entry(
            start=lunch_start,
            stop=lunch_end,
            description="",
            project_id=lunch_project_id,
        )

        # Start new entry from lunch end (running)
        provider.add_entry(
            start=lunch_end,
            stop=now,  # Current time
            description=running_entry.description,
            project_id=running_entry.project_id,
            tags=running_entry.tags,
        )

        return {
            "status": "added",
            "entries_modified": 1,
            "lunch_entry_id": lunch_entry.id,
        }

    if not overlapping:
        # No work during lunch time, just add lunch entry
        lunch_entry = provider.add_entry(
            start=lunch_start,
            stop=lunch_end,
            description="",
            project_id=lunch_project_id,
        )

        return {
            "status": "added",
            "entries_modified": 0,
            "lunch_entry_id": lunch_entry.id,
        }

    # Split overlapping entries
    entries_modified = 0

    for entry in overlapping:
        # Delete original entry
        provider.delete_entry(entry.id)
        entries_modified += 1

        # Create entry before lunch (if exists)
        if entry.start < lunch_start:
            provider.add_entry(
                start=entry.start,
                stop=lunch_start,
                description=entry.description,
                project_id=entry.project_id,
                tags=entry.tags,
            )

        # Create entry after lunch (if exists)
        if entry.stop > lunch_end:
            provider.add_entry(
                start=lunch_end,
                stop=entry.stop,
                description=entry.description,
                project_id=entry.project_id,
                tags=entry.tags,
            )

    # Add lunch entry
    lunch_entry = provider.add_entry(
        start=lunch_start,
        stop=lunch_end,
        description="",
        project_id=lunch_project_id,
    )

    return {
        "status": "added",
        "entries_modified": entries_modified,
        "lunch_entry_id": lunch_entry.id,
    }


def process_week_lunches(
    week_ref: str | None,
    provider: TimeTrackingProvider,
    lunch_project: str,
    dry_run: bool = False,
    timezone: str = "Europe/Oslo",
) -> dict[str, Any]:
    """Process lunch breaks for a week (Mon-Fri).

    Args:
        week_ref: Week reference (week number or date string) or None for current week
        provider: Time tracking provider
        lunch_project: Project name for lunch entries
        dry_run: If True, don't modify entries, just return summary
        timezone: IANA timezone for lunch time (default 'Europe/Oslo')

    Returns:
        Dictionary with summary:
        {
            "week_start": datetime,
            "days_processed": int,
            "days_added": int,
            "days_skipped_existing": int,
            "days_skipped_no_work": int,
            "details": list[dict]  # Per-day results
        }
    """
    monday = parse_week_reference(week_ref)

    summary: dict[str, Any] = {
        "week_start": monday,
        "days_processed": 0,
        "days_added": 0,
        "days_skipped_existing": 0,
        "days_skipped_no_work": 0,
        "details": [],
    }

    # Process Mon-Fri
    for day_offset in range(5):
        day = monday + timedelta(days=day_offset)
        summary["days_processed"] += 1

        if dry_run:
            # In dry-run, fetch entries but don't modify
            day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)
            entries = provider.get_entries(day_start, day_end)

            # Populate project names for filtering
            provider.populate_project_names(entries)

            # Check if lunch exists
            has_lunch = any(e.project == lunch_project for e in entries)

            # Check if work exists (including running entries)
            lunch_client = (
                lunch_project.split(" > ")[0] if " > " in lunch_project else lunch_project
            )
            has_work = any(
                e for e in entries if not (e.project and e.project.startswith(lunch_client))
            )

            if has_lunch:
                status = "skipped_existing"
            elif not has_work:
                status = "skipped_no_work"
            else:
                status = "would_add"

            result = {
                "date": day,
                "status": status,
                "entries_modified": 0,
            }
        else:
            # Actually insert lunch
            result = insert_lunch_break(day, provider, lunch_project, timezone=timezone)
            result["date"] = day

        # Update summary counts
        if result["status"] == "added" or result["status"] == "would_add":
            summary["days_added"] += 1
        elif result["status"] == "skipped_existing":
            summary["days_skipped_existing"] += 1
        elif result["status"] == "skipped_no_work":
            summary["days_skipped_no_work"] += 1

        summary["details"].append(result)

    return summary
