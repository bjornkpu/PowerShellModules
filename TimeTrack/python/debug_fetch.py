#!/usr/bin/env python3
"""Debug script to check what Toggl API returns for this week."""

from collections import defaultdict
from datetime import datetime, timedelta

from src.timetrack.config import load_config
from src.timetrack.providers import create_provider

config = load_config()
provider = create_provider(config)

# Get Monday of this week
monday = datetime(2026, 1, 26)
sunday_before = monday - timedelta(days=1)
saturday = monday + timedelta(days=5)

print("Fetching entries from Sunday to Saturday...")
print(f"Range: {sunday_before.date()} to {saturday.date()}\n")

entries = provider.get_entries(sunday_before, saturday)
provider.populate_project_names(entries)

print(f"Total entries: {len(entries)}\n")

# Group by date
by_date = defaultdict(list)
for entry in entries:
    if entry.stop:
        date = entry.start.astimezone().date()
        by_date[date].append(entry)

for date in sorted(by_date.keys()):
    total_hours = sum(e.duration_hours for e in by_date[date])
    print(f"\n{date.strftime('%A %Y-%m-%d')}: {total_hours:.2f}h")
    for entry in by_date[date]:
        start_local = entry.start.astimezone()
        stop_local = entry.stop.astimezone() if entry.stop else None
        stop_str = stop_local.strftime("%H:%M") if stop_local else "running"
        print(
            f"  {start_local.strftime('%H:%M')}-{stop_str}: "
            f"{entry.project} ({entry.duration_hours:.2f}h)"
        )
