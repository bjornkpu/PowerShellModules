"""Command-line interface for TimeTrack."""

from datetime import datetime

import typer

from . import __version__
from .config import get_lunch_project, get_lunch_timezone, load_config
from .core import process_week_lunches
from .providers import create_provider
from .utils import get_workdays_in_month

app = typer.Typer(
    name="timetrack",
    help="Time tracking automation with pluggable backends and multi-system reporting",
    add_completion=False,
)


def version_callback(value: bool):
    """Print version and exit."""
    if value:
        typer.echo(f"timetrack version {__version__}")
        raise typer.Exit()


@app.callback()
def main(
    version: bool = typer.Option(
        False,
        "--version",
        "-v",
        callback=version_callback,
        is_eager=True,
        help="Show version and exit",
    ),
):
    """TimeTrack CLI."""
    pass


@app.command(name="set-lunch")
def set_lunch(
    week: str = typer.Option(
        None,
        "--week",
        "-w",
        help="Week reference: week number (1-53) or date (YYYY-MM-DD). Defaults to current week.",
    ),
    dry_run: bool = typer.Option(
        False,
        "--dry-run",
        "-n",
        help="Preview changes without modifying entries",
    ),
):
    """Add lunch breaks to the week (Mon-Fri).

    Automatically detects work entries overlapping 11:00-11:30 and inserts
    30-minute lunch breaks, splitting entries as needed.

    Examples:
        timetrack set-lunch
        timetrack set-lunch --week 4
        timetrack set-lunch --week 2026-01-27 --dry-run
    """
    try:
        config = load_config()
        provider = create_provider(config)
        lunch_project = get_lunch_project(config)
        lunch_timezone = get_lunch_timezone(config)

        typer.echo(f"Processing lunch breaks for week {week or 'current'}...")
        if dry_run:
            typer.echo("DRY RUN - No changes will be made\n")

        summary = process_week_lunches(week, provider, lunch_project, dry_run, lunch_timezone)

        # Display results
        week_start = summary["week_start"].strftime("%Y-%m-%d")
        typer.echo(f"\nWeek starting: {week_start}")
        typer.echo(f"Days processed: {summary['days_processed']}")

        if dry_run:
            typer.echo(f"Would add lunch: {summary['days_added']} days")
        else:
            typer.echo(f"Lunch added: {summary['days_added']} days")

        typer.echo(f"Skipped (existing lunch): {summary['days_skipped_existing']} days")
        typer.echo(f"Skipped (no work): {summary['days_skipped_no_work']} days")

        # Show per-day details
        typer.echo("\nDaily breakdown:")
        for detail in summary["details"]:
            date_str = detail["date"].strftime("%a %d.%m")
            status = detail["status"]

            status_emoji = {
                "added": "✓",
                "would_add": "→",
                "skipped_existing": "○",
                "skipped_no_work": "-",
            }.get(status, "?")

            status_text = {
                "added": "Lunch added",
                "would_add": "Would add lunch",
                "skipped_existing": "Already has lunch",
                "skipped_no_work": "No work",
            }.get(status, status)

            typer.echo(f"  {status_emoji} {date_str}: {status_text}")

        if dry_run:
            typer.echo("\nRun without --dry-run to apply changes")
        else:
            typer.echo("\n✓ Lunch breaks updated successfully")

    except Exception as e:
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1) from e


@app.command()
def report(
    target: str = typer.Argument(
        ...,
        help="Target name from config (e.g., timereg, xledger, enova) or 'all'",
    ),
    week: str = typer.Option(
        None,
        "--week",
        "-w",
        help="Week reference: week number (1-53) or date (YYYY-MM-DD). Defaults to current week.",
    ),
):
    """Generate weekly timesheet reports for configured targets.

    Generates reports based on target configuration in config.json.
    Each target has a system type (TimeReg, xLedger, etc.) that determines the report format.

    Examples:
        timetrack report timereg
        timetrack report xledger --week 4
        timetrack report all --week 2026-01-27
    """
    try:
        config = load_config()
        provider = create_provider(config)

        from .config import get_enabled_targets, get_target_config
        from .reports.base import generate_system_report, get_week_entries

        # Get enabled targets
        enabled_targets = get_enabled_targets(config)

        if not enabled_targets:
            typer.echo("Error: No targets configured or enabled", err=True)
            raise typer.Exit(1)

        # Determine which targets to report
        if target == "all":
            targets_to_report = list(enabled_targets.keys())
        elif target in enabled_targets:
            targets_to_report = [target]
        else:
            valid_targets = list(enabled_targets.keys()) + ["all"]
            typer.echo(
                f"Error: Invalid target '{target}'. Valid options: {', '.join(valid_targets)}",
                err=True,
            )
            raise typer.Exit(1)

        # Fetch entries once (optimize API usage)
        monday, entries = get_week_entries(provider, week)

        # Get lunch client for filtering
        lunch_config = config.get("lunch", {})
        lunch_client = lunch_config.get("client", "Punsvik")

        # Generate reports for each target
        for target_name in targets_to_report:
            target_config = get_target_config(config, target_name)

            if not target_config:
                continue

            system = target_config.get("system", "Unknown")
            company = target_config.get("company", "Unknown")

            report_text = generate_system_report(
                system=system,
                company=company,
                target_name=target_name,
                monday=monday,
                entries=entries,
                target_config=target_config,
                lunch_client=lunch_client,
            )

            typer.echo(report_text)

            if len(targets_to_report) > 1:
                typer.echo("\n" + "=" * 60 + "\n")

    except Exception as e:
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1) from e


@app.command()
def remaining(
    month: int = typer.Option(
        None,
        "--month",
        "-m",
        help="Month number (1-12). Defaults to current month.",
        min=1,
        max=12,
    ),
):
    """Calculate remaining work hours for the month.

    Compares expected hours (7.5h × workdays) against actual tracked hours,
    accounting for Norwegian holidays and vacation days (empty past days).

    Examples:
        timetrack remaining
        timetrack remaining --month 1
    """
    try:
        config = load_config()
        provider = create_provider(config)

        now = datetime.now()
        year = now.year
        target_month = month or now.month

        # Get workdays in month (exclude future days)
        workdays = get_workdays_in_month(year, target_month, include_future=False)

        # Get all entries for the month (past only)
        if workdays:
            month_start = workdays[0]
            month_end = workdays[-1].replace(hour=23, minute=59, second=59)
            entries = provider.get_entries(month_start, month_end)
            # Populate project names for filtering
            provider.populate_project_names(entries)
        else:
            entries = []

        # Filter personal entries (e.g., lunch)
        lunch_project = get_lunch_project(config)
        lunch_client = lunch_project.split(" > ")[0] if " > " in lunch_project else lunch_project

        work_entries = [
            e for e in entries if e.stop and not (e.project and e.project.startswith(lunch_client))
        ]

        # Calculate actual and billable hours
        actual_hours = sum(e.duration_hours for e in work_entries)
        billable_hours = sum(e.duration_hours for e in work_entries if e.billable)

        # Detect vacation days (past workdays with 0 hours)
        dates_with_work = {e.start.date() for e in work_entries}
        vacation_days = [
            day
            for day in workdays
            if day.date() not in dates_with_work and day.date() <= now.date()
        ]

        # Calculate expected hours
        workdays_minus_vacation = len(workdays) - len(vacation_days)
        expected_hours = workdays_minus_vacation * 7.5

        # Get future workdays for remaining calculation
        future_workdays = get_workdays_in_month(year, target_month, include_future=True)
        future_only = [d for d in future_workdays if d.date() > now.date()]
        future_expected = len(future_only) * 7.5

        # Calculate difference
        difference = actual_hours - expected_hours

        # Display report
        month_name = datetime(year, target_month, 1).strftime("%B %Y")
        typer.echo(f"Work Hours Summary - {month_name}")
        typer.echo("=" * 50)
        typer.echo(f"Total workdays (past):       {len(workdays)}")
        typer.echo(f"Vacation days detected:      {len(vacation_days)}")
        typer.echo(f"Expected work days:          {workdays_minus_vacation}")
        typer.echo(f"Expected hours (7.5h/day):   {expected_hours:.1f}h")
        typer.echo(f"Actual hours tracked:        {actual_hours:.1f}h")
        typer.echo("-" * 50)

        if difference > 0:
            typer.echo(f"Ahead by:                    +{difference:.1f}h")
        elif difference < 0:
            typer.echo(f"Behind by:                   {difference:.1f}h")
        else:
            typer.echo(f"On track:                    {difference:.1f}h")

        # Billable breakdown
        billable_diff = billable_hours - expected_hours
        billable_pct = (billable_hours / expected_hours * 100) if expected_hours > 0 else 0
        typer.echo("")
        typer.echo(f"Billable hours:              {billable_hours:.1f}h")
        billable_sign = "+" if billable_diff >= 0 else ""
        typer.echo(f"Billable vs expected:        {billable_sign}{billable_diff:.1f}h")
        typer.echo(f"Billable % of expected:      {billable_pct:.1f}%")

        typer.echo("\n" + "=" * 50)
        typer.echo(f"Remaining workdays:          {len(future_only)}")
        typer.echo(f"Remaining expected hours:    {future_expected:.1f}h")

        if len(future_only) > 0:
            needed_daily = (future_expected - difference) / len(future_only)
            typer.echo(f"Needed per day to finish:    {needed_daily:.1f}h")

            total_expected = expected_hours + future_expected
            billable_needed = (total_expected - billable_hours) / len(future_only)
            typer.echo(f"Needed billable/day for 100%: {billable_needed:.1f}h")

    except Exception as e:
        typer.echo(f"Error: {e}", err=True)
        raise typer.Exit(1) from e


if __name__ == "__main__":
    app()
