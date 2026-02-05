"""Utility functions for date/time handling."""

from datetime import datetime, timedelta

import holidays
from dateutil import parser as date_parser


def parse_week_reference(week_ref: str | None) -> datetime:
    """Parse week reference to Monday date.

    Supports:
    - Week number: "4", "W04" -> ISO week 4 (Monday)
    - Date: "2026-01-27" -> Monday of that week
    - None: Current week Monday

    Args:
        week_ref: Week reference string or None

    Returns:
        datetime object for Monday of the week
    """
    if week_ref is None:
        # Current week Monday at midnight
        today = datetime.now()
        monday = today - timedelta(days=today.weekday())
        return monday.replace(hour=0, minute=0, second=0, microsecond=0)

    # Try parsing as week number
    week_ref = week_ref.strip().upper().lstrip("W")

    try:
        week_num = int(week_ref)
        # ISO week: Use current year, find Monday of that week
        year = datetime.now().year

        # ISO week starts with the week containing the first Thursday
        jan4 = datetime(year, 1, 4)
        week1_monday = jan4 - timedelta(days=jan4.weekday())

        target_monday = week1_monday + timedelta(weeks=week_num - 1)
        return target_monday.replace(hour=0, minute=0, second=0, microsecond=0)

    except ValueError:
        # Try parsing as date
        try:
            date = date_parser.parse(week_ref)
            # Return Monday of that week at midnight
            monday = date - timedelta(days=date.weekday())
            return monday.replace(hour=0, minute=0, second=0, microsecond=0)
        except (ValueError, date_parser.ParserError) as e:
            raise ValueError(
                f"Invalid week reference: {week_ref}. "
                f"Expected week number (1-53) or date (YYYY-MM-DD)"
            ) from e


def get_workdays_in_month(year: int, month: int, include_future: bool = True) -> list[datetime]:
    """Get list of workdays (Mon-Fri) in a month, excluding Norwegian holidays.

    Args:
        year: Year
        month: Month (1-12)
        include_future: If True, include future dates; if False, only past/today

    Returns:
        List of datetime objects for workdays
    """
    no_holidays = holidays.country_holidays("NO", years=year)

    # First and last day of month
    first_day = datetime(year, month, 1)

    if month == 12:
        last_day = datetime(year + 1, 1, 1) - timedelta(days=1)
    else:
        last_day = datetime(year, month + 1, 1) - timedelta(days=1)

    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    workdays = []

    current = first_day
    while current <= last_day:
        # Check if weekday (Mon=0, Sun=6)
        if current.weekday() < 5:  # Mon-Fri
            # Check if not a holiday
            if current.date() not in no_holidays:
                # Check future filter
                if include_future or current <= today:
                    workdays.append(current)

        current += timedelta(days=1)

    return workdays


def round_hours(hours: float, rounding: float = 0.5) -> float:
    """Round hours to nearest increment.

    Args:
        hours: Hours to round
        rounding: Rounding increment (e.g., 0.5 for 30min, 0.25 for 15min)

    Returns:
        Rounded hours
    """
    return round(hours / rounding) * rounding
