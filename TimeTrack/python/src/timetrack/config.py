"""Configuration management for TimeTrack."""

import json
import shutil
from pathlib import Path
from typing import Any


def load_config() -> dict[str, Any]:
    """Load configuration from standard config location.

    Automatically creates config from example on first run.

    Returns:
        Configuration dictionary

    Raises:
        ValueError: If config is invalid JSON or contains placeholders
    """
    # Use standard config path: $env:USERPROFILE\.config\TimeTrack\config.json
    user_home = Path.home()
    config_dir = user_home / ".config" / "TimeTrack"
    config_file = config_dir / "config.json"

    if not config_file.exists():
        # Create config directory
        config_dir.mkdir(parents=True, exist_ok=True)

        # Find module root (go up from src/timetrack to TimeTrack root)
        module_root = Path(__file__).parent.parent.parent.parent
        example_config = module_root / "config.example.json"

        if not example_config.exists():
            raise FileNotFoundError(
                f"Config example not found at {example_config}\n"
                f"Module installation may be corrupted."
            )

        # Copy example to config location
        shutil.copy(example_config, config_file)

        # Print instructions and exit gracefully (first run is not an error)
        print(f"✓ Config created at: {config_file}\n")
        print("Please edit the config file and replace placeholder values:")
        print("  - toggl.apiToken: Get from https://track.toggl.com/profile")
        print("  - toggl.workspaceId: Your Toggl workspace ID")
        print("  - projectMappings: Map your Toggl projects to timesheet systems")
        print("\nThen run the command again.")
        raise SystemExit(0)

    try:
        with open(config_file, encoding="utf-8") as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in config file: {e}") from e

    # Check for placeholder values
    if "<your-toggl-api-token>" in json.dumps(config):
        raise ValueError(
            f"Config contains placeholder values: {config_file}\n\n"
            f"Please edit the config and replace:\n"
            f"  - <your-toggl-api-token> with your actual Toggl API token\n"
            f"  - Update workspaceId, projectMappings, etc.\n\n"
            f"Get your API token from: https://track.toggl.com/profile"
        )

    return config


def get_lunch_project(config: dict[str, Any]) -> str:
    """Get lunch project name from config."""
    # Try new structure first, fall back to old structure
    lunch_config = config.get("lunch", {})
    return lunch_config.get("project") or config.get("lunchProject", "Lunch")


def get_lunch_timezone(config: dict[str, Any]) -> str:
    """Get IANA timezone for lunch scheduling from config.

    Args:
        config: Configuration dictionary

    Returns:
        IANA timezone string (e.g., 'Europe/Oslo'), defaults to 'Europe/Oslo'
    """
    lunch_config = config.get("lunch", {})
    return lunch_config.get("timezone", "Europe/Oslo")


def get_reporting_rules(config: dict[str, Any], system: str) -> dict[str, Any]:
    """Get reporting rules for specific system (old config structure).

    Args:
        config: Configuration dictionary
        system: System name (timereg, xledger, enova)

    Returns:
        Reporting rules dictionary with rounding, aggregate flags
    """
    rules = config.get("reportingRules", {}).get(system, {})

    # Set defaults
    if "rounding" not in rules:
        rules["rounding"] = 0.5

    if system == "timereg" and "aggregate" not in rules:
        rules["aggregate"] = True

    return rules


def get_enabled_targets(config: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Get all enabled reporting targets from config.

    Args:
        config: Configuration dictionary

    Returns:
        Dictionary of enabled targets {target_name: target_config}
    """
    targets = config.get("targets", {})
    return {name: cfg for name, cfg in targets.items() if cfg.get("enabled", True)}


def get_target_config(config: dict[str, Any], target_name: str) -> dict[str, Any] | None:
    """Get configuration for a specific target.

    Args:
        config: Configuration dictionary
        target_name: Name of the target (e.g., 'timereg', 'xledger')

    Returns:
        Target configuration or None if not found
    """
    return config.get("targets", {}).get(target_name)


def get_target_project_mapping(target_config: dict[str, Any], source_project: str) -> str | None:
    """Get project mapping for a target.

    Args:
        target_config: Target configuration dictionary
        source_project: Source project name (from Toggl, etc.)

    Returns:
        Mapped project name/code or None if not mapped
    """
    mappings = target_config.get("projectMappings", {})
    return mappings.get(source_project)


def get_project_mapping(config: dict[str, Any], toggl_project: str) -> dict[str, Any] | None:
    """Get project mapping for a Toggl project (old config structure).

    Args:
        config: Configuration dictionary
        toggl_project: Toggl project name

    Returns:
        Project mapping dict or None if not found
    """
    mappings = config.get("projectMappings", [])

    for mapping in mappings:
        if mapping.get("togglProject") == toggl_project:
            return mapping

    return None
