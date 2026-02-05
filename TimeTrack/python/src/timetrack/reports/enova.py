"""Enova reporting - separate rows per project per day."""

from collections import defaultdict
from datetime import datetime, timedelta
from typing import Any

from ..config import get_project_mapping, get_reporting_rules
from ..providers.base import TimeEntry, TimeTrackingProvider
from ..utils import round_hours
from .base import filter_personal_entries, format_table, get_week_entries


def generate_enova_report(
    provider: TimeTrackingProvider,
    config: dict[str, Any],
    week_ref: str | None = None,
    entries: list[TimeEntry] | None = None,
    monday: datetime | None = None,
) -> str:
    """Generate Enova report with separate project rows per day.

    Args:
        provider: Time tracking provider
        config: Configuration dictionary
        week_ref: Week reference or None for current week
        entries: Optional pre-fetched entries (to avoid redundant API calls)
        monday: Optional monday date (must be provided if entries is provided)

    Returns:
        Formatted report string
    """
    # Fetch entries if not provided
    if entries is None:
        monday, entries = get_week_entries(provider, week_ref)
    elif monday is None:
        raise ValueError("monday must be provided when entries is provided")

    rules = get_reporting_rules(config, "enova")
    rounding = rules.get("rounding", 0.5)

    # Filter personal entries
    work_entries = filter_personal_entries(entries)

    # Group by date and project
    daily_projects: dict[datetime, dict[str, float]] = defaultdict(lambda: defaultdict(float))

    for entry in work_entries:
        if entry.stop is None:
            continue

        date = entry.start.replace(hour=0, minute=0, second=0, microsecond=0)

        # Get project mapping
        mapping = get_project_mapping(config, entry.project or "")

        if not mapping:
            # Skip unmapped projects
            continue

        enova_project = mapping.get("enova")
        if not enova_project:
            # No Enova mapping for this project
            continue

        daily_projects[date][enova_project] += entry.duration_hours

    # Build table rows
    headers = ["Day", "Project", "Hours"]
    rows = []
    total_hours = 0.0

    for day_offset in range(5):
        date = monday + timedelta(days=day_offset)
        day_name = date.strftime("%a %d.%m")

        if date in daily_projects:
            projects = daily_projects[date]

            # Sort projects for consistent order
            for project_code in sorted(projects.keys()):
                hours = projects[project_code]
                rounded_hours = round_hours(hours, rounding)
                total_hours += rounded_hours
                rows.append([day_name, project_code, f"{rounded_hours:.1f}"])
        else:
            rows.append([day_name, "-", "0.0"])

    # Add total
    rows.append(["", "TOTAL", f"{total_hours:.1f}"])

    week_str = monday.strftime("Week %W, %Y")
    title = f"Enova Report - {week_str}"

    return format_table(headers, rows, title)


__all__ = ["generate_enova_report"]
