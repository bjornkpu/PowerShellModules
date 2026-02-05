#!/usr/bin/env python3
"""Capture real Toggl API response for testing."""

import base64
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import httpx

from src.timetrack.config import load_config

config = load_config()
source = config.get("source", {})
api_token = source.get("apiToken")

if not api_token:
    print("No API token found in config")
    exit(1)

# Get this week's date range
local_tz = ZoneInfo("Europe/Oslo")
monday = datetime(2026, 1, 26).replace(tzinfo=local_tz)
saturday = monday + timedelta(days=5)

# Convert to UTC for API
start_utc = monday.astimezone(timezone.utc)
end_utc = saturday.astimezone(timezone.utc)

print(f"Fetching entries from {start_utc} to {end_utc}")
print(f"Local time: {monday} to {saturday}")

# Make API request
auth_str = f"{api_token}:api_token"
auth_bytes = auth_str.encode("ascii")
auth_b64 = "Basic " + base64.b64encode(auth_bytes).decode("ascii")

client = httpx.Client(
    headers={
        "Authorization": auth_b64,
        "Content-Type": "application/json",
    },
    timeout=30.0,
)

url = "https://api.track.toggl.com/api/v9/me/time_entries"
params = {
    "start_date": start_utc.isoformat(),
    "end_date": end_utc.isoformat(),
}

response = client.get(url, params=params)
print(f"\nStatus: {response.status_code}")
print(f"Quota remaining: {response.headers.get('X-Toggl-Quota-Remaining')}")

if response.status_code == 200:
    data = response.json()
    print(f"Entries received: {len(data)}")

    # Save to file
    output_file = Path(__file__).parent / "tests" / "fixtures" / "toggl_week_response.json"
    output_file.parent.mkdir(parents=True, exist_ok=True)

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    print(f"\nSaved response to: {output_file}")

    # Show summary
    print("\nEntries summary:")
    for entry in data:
        start = entry["start"]
        stop = entry.get("stop", "running")
        duration = entry["duration"]
        project_id = entry.get("project_id")
        desc = entry.get("description", "")
        print(f"  {start} -> {stop}: project_id={project_id}, duration={duration}s, desc={desc}")
else:
    print(f"Error: {response.text}")
