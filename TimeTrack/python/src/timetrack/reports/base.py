"""Base reporting functionality."""

from datetime import datetime, timedelta

from ..providers.base import TimeEntry, TimeTrackingProvider
from ..utils import parse_week_reference, round_hours


def get_week_entries(
    provider: TimeTrackingProvider,
    week_ref: str | None,
) -> tuple[datetime, list[TimeEntry]]:
    """Get all entries for a week (Mon-Fri).

    Args:
        provider: Time tracking provider
        week_ref: Week reference or None for current week

    Returns:
        Tuple of (monday_date, entries_list)
    """
    monday = parse_week_reference(week_ref)
    friday = monday + timedelta(days=4)
    end_of_friday = friday + timedelta(days=1)

    entries = provider.get_entries(monday, end_of_friday)
    # Populate project names for filtering
    provider.populate_project_names(entries)

    return monday, entries


def filter_personal_entries(
    entries: list[TimeEntry],
    personal_client: str = "Punsvik",
) -> list[TimeEntry]:
    """Filter out personal entries (e.g., lunch).

    Args:
        entries: List of time entries
        personal_client: Client name to exclude (default: Punsvik)

    Returns:
        Filtered list of entries
    """
    return [e for e in entries if not (e.project and e.project.startswith(personal_client))]


def format_table(headers: list[str], rows: list[list[str]], title: str = "") -> str:
    """Format data as plain text table.

    Args:
        headers: Column headers
        rows: Data rows
        title: Optional table title

    Returns:
        Formatted table string
    """
    # Calculate column widths
    col_widths = [len(h) for h in headers]

    for row in rows:
        for i, cell in enumerate(row):
            col_widths[i] = max(col_widths[i], len(cell))

    # Build table
    lines = []

    if title:
        lines.append(title)
        lines.append("=" * len(title))
        lines.append("")

    # Header
    header_line = " | ".join(h.ljust(col_widths[i]) for i, h in enumerate(headers))
    lines.append(header_line)

    # Separator
    separator = "-+-".join("-" * w for w in col_widths)
    lines.append(separator)

    # Rows
    for row in rows:
        row_line = " | ".join(str(cell).ljust(col_widths[i]) for i, cell in enumerate(row))
        lines.append(row_line)

    return "\n".join(lines)


def generate_system_report(
    system: str,
    company: str,
    target_name: str,
    monday: datetime,
    entries: list[TimeEntry],
    target_config: dict,
    lunch_client: str,
) -> str:
    """Generate report based on system type.

    Args:
        system: System type (e.g., 'TimeReg', 'xLedger')
        company: Company name for the report title
        target_name: Target configuration name
        monday: Monday date of the week
        entries: Time entries for the week
        target_config: Target configuration with rounding and project mappings
        lunch_client: Client name to filter out (e.g., 'Punsvik')

    Returns:
        Formatted report string
    """

    rounding = target_config.get("rounding", 0.5)

    # Filter personal entries
    work_entries = [e for e in entries if not (e.project and e.project.startswith(lunch_client))]

    # System-specific formatting
    if system.lower() in ["timereg", "xledger"]:
        return _generate_pivoted_report(
            system, company, target_name, monday, work_entries, target_config, rounding
        )
    else:
        # Future: other system formats
        return _generate_pivoted_report(
            system, company, target_name, monday, work_entries, target_config, rounding
        )


def _generate_pivoted_report(
    system: str,
    company: str,
    target_name: str,
    monday: datetime,
    work_entries: list[TimeEntry],
    target_config: dict,
    rounding: float,
) -> str:
    """Generate pivoted report (projects as rows, days as columns)."""
    from collections import defaultdict
    from datetime import date
    from zoneinfo import ZoneInfo

    from ..config import get_target_project_mapping

    # Use local timezone for date grouping
    local_tz = ZoneInfo("Europe/Oslo")

    # Group by project and date (using date objects, not datetime)
    project_daily_hours: dict[str, dict[date, float]] = defaultdict(lambda: defaultdict(float))

    for entry in work_entries:
        if entry.stop is None:
            continue

        # Convert to local timezone before extracting date
        entry_local = entry.start.astimezone(local_tz)
        entry_date = entry_local.date()

        # Get project mapping for this target
        mapped_project = get_target_project_mapping(target_config, entry.project or "")

        if not mapped_project:
            # Skip unmapped projects
            continue

        project_daily_hours[mapped_project][entry_date] += entry.duration_hours

    # Build table with projects as rows, days as columns
    weekdays = [(monday + timedelta(days=i)).date() for i in range(5)]
    day_names = [d.strftime("%a %d.%m") for d in weekdays]

    headers = ["Project"] + day_names + ["Total"]
    rows = []

    # Get project mappings to preserve order from config
    project_mappings = target_config.get("projectMappings", {})
    # Use the order of values in the mapping (target project names)
    ordered_projects = list(dict.fromkeys(project_mappings.values()))
    # Filter to only projects that have hours
    projects_to_show = [p for p in ordered_projects if p in project_daily_hours]

    for project in projects_to_show:
        row = [project]

        # Add hours for each day
        day_totals = []
        for day_date in weekdays:
            hours = project_daily_hours[project].get(day_date, 0.0)
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
        for day_date in weekdays:
            day_total = sum(
                project_daily_hours[proj].get(day_date, 0.0) for proj in project_daily_hours.keys()
            )
            rounded = round_hours(day_total, rounding)
            total_row.append(f"{rounded:.1f}" if rounded > 0 else "-")

        # Grand total
        grand_total = sum(sum(hours.values()) for hours in project_daily_hours.values())
        rounded_grand = round_hours(grand_total, rounding)
        total_row.append(f"{rounded_grand:.1f}")
        rows.append(total_row)

    week_str = monday.strftime("Week %W, %Y")
    title = f"{company} {system} Report - {week_str}"

    return format_table(headers, rows, title)
