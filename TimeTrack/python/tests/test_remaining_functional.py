"""Functional test for the 'remaining' command - hits real Toggl API."""

import json
from datetime import datetime

import pytest

from timetrack.config import get_lunch_project, load_config
from timetrack.providers import create_provider
from timetrack.utils import get_workdays_in_month


def test_remaining_api_response():
    """Run the remaining logic and dump raw API data for debugging."""
    config = load_config()
    provider = create_provider(config)

    now = datetime.now()
    year = now.year
    target_month = now.month

    # Get workdays (past only)
    workdays = get_workdays_in_month(year, target_month, include_future=False)

    if not workdays:
        pytest.skip("No past workdays in current month")

    month_start = workdays[0]
    month_end = workdays[-1].replace(hour=23, minute=59, second=59)

    print(f"\n{'=' * 60}")
    print(f"Querying: {month_start} -> {month_end}")
    print(f"{'=' * 60}")

    # Raw API call - get entries
    entries = provider.get_entries(month_start, month_end)

    print(f"\nRaw entries count: {len(entries)}")
    print(f"\nFirst 5 raw entries:")
    for i, e in enumerate(entries[:5]):
        print(
            f"  [{i}] id={e.id} start={e.start} stop={e.stop} "
            f"duration={e.duration} project_id={e.project_id} "
            f"desc='{e.description}'"
        )

    # Populate project names
    provider.populate_project_names(entries)

    print(f"\nAfter project name population:")
    for i, e in enumerate(entries[:5]):
        print(f"  [{i}] project='{e.project}' project_id={e.project_id}")

    # Filter lunch
    lunch_project = get_lunch_project(config)
    lunch_client = lunch_project.split(" > ")[0] if " > " in lunch_project else lunch_project

    print(f"\nLunch project: '{lunch_project}'")
    print(f"Lunch client filter: '{lunch_client}'")

    work_entries = [
        e for e in entries if e.stop and not (e.project and e.project.startswith(lunch_client))
    ]
    lunch_entries = [e for e in entries if e.project and e.project.startswith(lunch_client)]

    billable_entries = [e for e in work_entries if e.billable]

    print(f"\nWork entries: {len(work_entries)}")
    print(f"Billable entries: {len(billable_entries)}")
    print(f"Lunch entries: {len(lunch_entries)}")
    print(f"Running (no stop): {len([e for e in entries if not e.stop])}")

    # Actual hours
    actual_hours = sum(e.duration_hours for e in work_entries)
    billable_hours = sum(e.duration_hours for e in billable_entries)

    # Vacation detection
    dates_with_work = {e.start.date() for e in work_entries}
    vacation_days = [
        day for day in workdays if day.date() not in dates_with_work and day.date() <= now.date()
    ]

    # Expected hours
    workdays_minus_vacation = len(workdays) - len(vacation_days)
    expected_hours = workdays_minus_vacation * 7.5

    # Future workdays
    future_workdays = get_workdays_in_month(year, target_month, include_future=True)
    future_only = [d for d in future_workdays if d.date() > now.date()]
    future_expected = len(future_only) * 7.5

    difference = actual_hours - expected_hours

    print(f"\n{'=' * 60}")
    print(f"RESULTS")
    print(f"{'=' * 60}")
    print(f"Workdays (past):           {len(workdays)}")
    print(f"Vacation days:             {len(vacation_days)}")
    if vacation_days:
        for v in vacation_days:
            print(f"  - {v.strftime('%a %d.%m')}")
    print(f"Expected work days:        {workdays_minus_vacation}")
    print(f"Expected hours:            {expected_hours:.1f}h")
    print(f"Actual hours:              {actual_hours:.1f}h")
    print(f"Billable hours:            {billable_hours:.1f}h")
    billable_pct = (billable_hours / expected_hours * 100) if expected_hours > 0 else 0
    print(f"Billable % of expected:    {billable_pct:.1f}%")
    print(f"Difference:                {difference:+.1f}h")
    print(f"Future workdays:           {len(future_only)}")
    print(f"Future expected:           {future_expected:.1f}h")
    if future_only:
        needed_daily = (future_expected - difference) / len(future_only)
        print(f"Needed per day:            {needed_daily:.1f}h")

    # Per-day breakdown
    print(f"\n{'=' * 60}")
    print(f"PER-DAY BREAKDOWN")
    print(f"{'=' * 60}")
    from collections import defaultdict

    daily_hours = defaultdict(float)
    for e in work_entries:
        daily_hours[e.start.date()] += e.duration_hours

    for day in workdays:
        d = day.date()
        hours = daily_hours.get(d, 0)
        marker = " (vacation?)" if hours == 0 and d <= now.date() else ""
        print(f"  {day.strftime('%a %d.%m')}: {hours:.1f}h{marker}")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
