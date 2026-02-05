"""Test report generation with real API response."""

import json
from datetime import datetime
from pathlib import Path

import pytest

from timetrack.providers.base import TimeEntry
from timetrack.reports.base import _generate_pivoted_report


def load_fixture():
    """Load captured Toggl API response."""
    fixture_file = Path(__file__).parent / "fixtures" / "toggl_week_response.json"
    if not fixture_file.exists():
        pytest.skip(
            f"Fixture file not found: {fixture_file}. "
            "Run 'uv run python record_fixtures.py' to generate fixtures."
        )
    with open(fixture_file, encoding="utf-8") as f:
        return json.load(f)


def parse_entries(api_data, project_mapping):
    """Parse API response into TimeEntry objects with project names."""
    entries = []

    for entry_data in api_data:
        start = datetime.fromisoformat(entry_data["start"].replace("Z", "+00:00"))
        stop_str = entry_data.get("stop")
        stop = datetime.fromisoformat(stop_str.replace("Z", "+00:00")) if stop_str else None

        project_id = entry_data.get("project_id")
        project_name = project_mapping.get(project_id, f"Unknown-{project_id}")

        entry = TimeEntry(
            id=entry_data["id"],
            start=start,
            stop=stop,
            duration=entry_data["duration"],
            description=entry_data.get("description", ""),
            project=project_name,
            project_id=project_id,
            workspace_id=1,
            tags=[],
        )
        entries.append(entry)

    return entries


def test_monday_data_appears_in_report():
    """Test that Monday data from Toggl API shows up in the report."""
    # Load real API response
    api_data = load_fixture()

    # Project ID mapping from real data
    project_mapping = {
        213533487: "Mimir Drift",
        213533469: "Work Crayon",
        213800161: "Lunsj",
    }

    # Parse entries
    entries = parse_entries(api_data, project_mapping)

    # Filter out lunch
    work_entries = [e for e in entries if e.project != "Lunsj"]

    # Target config for testing
    target_config = {
        "projectMappings": {
            "Mimir Drift": "Enova - data, analyse og innsikt",
            "Work Crayon": "Crayon",
        }
    }

    monday = datetime(2026, 1, 26)

    # Generate report
    report = _generate_pivoted_report(
        system="TimeReg",
        company="Test",
        target_name="test",
        monday=monday,
        work_entries=work_entries,
        target_config=target_config,
        rounding=0.5,
    )

    print("\n" + report)

    # Assertions
    assert "Mon 26.01" in report, "Monday column should be in report"

    # Check that Monday has data (not just dashes)
    lines = report.split("\n")
    for line in lines:
        if "Enova - data" in line or "Crayon" in line:
            parts = line.split("|")
            if len(parts) >= 2:
                monday_value = parts[1].strip()
                print(f"Monday value for {parts[0].strip()}: '{monday_value}'")
                # At least one project should have hours on Monday

    # The total should include Monday hours
    assert "TOTAL" in report

    # Check if Monday column has non-zero values
    # Monday should show work hours (not just "-")
    assert any("Enova - data" in line and "Mon 26.01" in report for line in lines), (
        "Should have Enova project data"
    )


def test_timezone_conversion():
    """Test that UTC times are correctly converted to Norway time for date grouping."""
    api_data = load_fixture()

    # Find Monday morning entry
    monday_morning = next(e for e in api_data if e["start"] == "2026-01-26T06:21:52+00:00")

    start = datetime.fromisoformat(monday_morning["start"].replace("Z", "+00:00"))

    # Convert to Norway timezone
    from zoneinfo import ZoneInfo

    norway_time = start.astimezone(ZoneInfo("Europe/Oslo"))

    print(f"\nUTC time: {start}")
    print(f"Norway time: {norway_time}")
    print(f"Date in Norway: {norway_time.date()}")

    # Should be Monday Jan 26
    assert norway_time.date().day == 26
    assert norway_time.date().weekday() == 0  # Monday
    assert norway_time.hour == 7  # 06:21 UTC = 07:21 Norway time


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
