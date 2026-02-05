"""Provider factory for creating time tracking backend instances."""

from typing import Any

from .base import TimeTrackingProvider
from .mock import MockProvider
from .recording_mock import RecordingMockProvider
from .toggl import TogglProvider


def create_provider(config: dict[str, Any]) -> TimeTrackingProvider:
    """Create time tracking provider from config.

    Args:
        config: Configuration dictionary

    Returns:
        Provider instance

    Raises:
        ValueError: If backend not supported
    """
    # Get backend from source config (new structure) or root (old structure)
    source = config.get("source", {})
    backend = source.get("backend") or config.get("backend", "toggl")

    if backend == "mock":
        workspace_id = source.get("workspaceId", 1)
        return MockProvider(workspace_id=workspace_id)

    if backend == "fixtures":
        # Use recorded API responses
        return RecordingMockProvider()

    if backend == "toggl":
        # Try new structure first, fall back to old structure
        api_token = source.get("apiToken") or config.get("toggl", {}).get("apiToken")
        workspace_id = source.get("workspaceId") or config.get("toggl", {}).get("workspaceId")

        if not api_token:
            raise ValueError("Toggl API token not configured")
        if not workspace_id:
            raise ValueError("Toggl workspace ID not configured")

        return TogglProvider(api_token=api_token, workspace_id=workspace_id)

    raise ValueError(f"Unsupported backend: {backend}")


__all__ = [
    "create_provider",
    "TimeTrackingProvider",
    "TogglProvider",
    "MockProvider",
    "RecordingMockProvider",
]
