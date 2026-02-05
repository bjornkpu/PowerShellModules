#!/usr/bin/env python3
"""Record all API responses needed for offline development."""

import base64
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import httpx

from src.timetrack.config import load_config

# Load config
config = load_config()
source = config.get("source", {})
api_token = source.get("apiToken")
workspace_id = source.get("workspaceId")

if not api_token:
    print("No API token found in config")
    exit(1)

# Setup
fixtures_dir = Path(__file__).parent / "tests" / "fixtures"
fixtures_dir.mkdir(parents=True, exist_ok=True)

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

base_url = "https://api.track.toggl.com/api/v9"

print("Recording API responses...")
print(f"Quota before: {client.get(base_url + '/me').headers.get('X-Toggl-Quota-Remaining')}/30\n")

# 1. Get time entries for this week
local_tz = ZoneInfo("Europe/Oslo")
monday = datetime(2026, 1, 26).replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=local_tz)
saturday = monday + timedelta(days=6)

start_utc = monday.astimezone(timezone.utc)
end_utc = saturday.astimezone(timezone.utc)

print(f"1. Fetching time entries ({monday.date()} to {saturday.date()})...")
response = client.get(
    f"{base_url}/me/time_entries",
    params={
        "start_date": start_utc.isoformat(),
        "end_date": end_utc.isoformat(),
    },
)

if response.status_code == 200:
    entries_data = response.json()

    with open(fixtures_dir / "toggl_entries.json", "w", encoding="utf-8") as f:
        json.dump(entries_data, f, indent=2)

    print(f"   ✓ Saved {len(entries_data)} entries to toggl_entries.json")

    # Extract unique project IDs
    project_ids = {e.get("project_id") for e in entries_data if e.get("project_id")}
else:
    print(f"   ✗ Error: {response.status_code} - {response.text}")
    project_ids = set()

# 2. Get projects
print(f"\n2. Fetching projects (workspace {workspace_id})...")
response = client.get(f"{base_url}/workspaces/{workspace_id}/projects")

if response.status_code == 200:
    projects_data = response.json()

    # Filter to only projects we actually use
    used_projects = [p for p in projects_data if p["id"] in project_ids]

    with open(fixtures_dir / "toggl_projects.json", "w", encoding="utf-8") as f:
        json.dump(used_projects, f, indent=2)

    print(f"   ✓ Saved {len(used_projects)} projects to toggl_projects.json")
else:
    print(f"   ✗ Error: {response.status_code} - {response.text}")

# Check final quota
print("\n✓ Recording complete!")
final_response = client.get(base_url + "/me")
print(f"Quota after: {final_response.headers.get('X-Toggl-Quota-Remaining')}/30")
print(f"\nFixtures saved to: {fixtures_dir}")
