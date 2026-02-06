"""xledger reporting - separate rows per project per day."""

from collections import defaultdict
from datetime import datetime, timedelta
from typing import Any

from ..config import get_project_mapping, get_reporting_rules
from ..providers.base import TimeEntry, TimeTrackingProvider
from ..utils import round_hours
from .base import filter_personal_entries, format_table, get_week_entries


def generate_xledger_report(
    provider: TimeTrackingProvider,
    config: dict[str, Any],
    week_ref: str | None = None,
    entries: list[TimeEntry] | None = None,
    monday: datetime | None = None,
) -> str:
    """Generate xledger report with separate project rows per day.

    Projects are shown as rows, days as columns (matching TimeReg/xLedger format).

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

    rules = get_reporting_rules(config, "xledger")
    rounding = rules.get("rounding", 0.5)

    # Filter personal entries
    work_entries = filter_personal_entries(entries)

    # Group by project and date
    project_daily_hours: dict[str, dict[datetime, float]] = defaultdict(lambda: defaultdict(float))

    for entry in work_entries:
        if entry.stop is None:
            continue

        date = entry.start.replace(hour=0, minute=0, second=0, microsecond=0)

        # Get project mapping
        mapping = get_project_mapping(config, entry.project or "")

        if not mapping:
            # Skip unmapped projects
            continue

        xledger_project = mapping.get("xledger")
        if not xledger_project:
            # No xledger mapping for this project
            continue

        project_daily_hours[xledger_project][date] += entry.duration_hours

    # Build table with projects as rows, days as columns
    weekdays = [monday + timedelta(days=i) for i in range(5)]
    day_names = [d.strftime("%a %d.%m") for d in weekdays]

    headers = ["Project"] + day_names + ["Total"]
    rows = []

    # Sort projects alphabetically
    for project in sorted(project_daily_hours.keys()):
        row = [project]

        # Add hours for each day
        day_totals = []
        for date in weekdays:
            hours = project_daily_hours[project].get(date, 0.0)
            rounded = round_hours(hours, rounding)
            day_totals.append(rounded)
            row.append(f"{rounded:.1f}" if rounded > 0 else "-")

        # Add project total
        project_total = sum(day_totals)
        row.append(f"{project_total:.1f}")
        rows.append(row)

    # Add total row
    if rows:
        total_row = ["TOTAL"]
        for date in weekdays:
            day_total = sum(
                project_daily_hours[proj].get(date, 0.0) for proj in project_daily_hours.keys()
            )
            rounded = round_hours(day_total, rounding)
            total_row.append(f"{rounded:.1f}" if rounded > 0 else "-")

        # Grand total
        grand_total = sum(sum(hours.values()) for hours in project_daily_hours.values())
        rounded_grand = round_hours(grand_total, rounding)
        total_row.append(f"{rounded_grand:.1f}")
        rows.append(total_row)

    week_str = monday.strftime("Week %V, %G")
    title = f"xledger Report - {week_str}"

    return format_table(headers, rows, title)


__all__ = ["generate_xledger_report"]
