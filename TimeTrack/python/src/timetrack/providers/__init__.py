"""Provider factory for creating time tracking backend instances."""

from typing import Any

from ..config import get_active_source
from .base import TimeTrackingProvider
from .mock import MockProvider
from .recording_mock import RecordingMockProvider
from .solidtime import SolidtimeProvider
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
    backend, source = get_active_source(config)

    if backend == "mock":
        workspace_id = source.get("workspaceId", 1)
        return MockProvider(workspace_id=workspace_id)

    if backend == "fixtures":
        return RecordingMockProvider()

    if backend == "toggl":
        api_token = source.get("apiToken")
        workspace_id = source.get("workspaceId")

        if not api_token:
            raise ValueError("Toggl API token not configured")
        if not workspace_id:
            raise ValueError("Toggl workspace ID not configured")

        return TogglProvider(api_token=api_token, workspace_id=workspace_id)

    if backend == "solidtime":
        base_url = source.get("baseUrl")
        api_key = source.get("apiKey")
        organization_id = source.get("organizationId")
        member_id = source.get("memberId")

        if not all([base_url, api_key, organization_id, member_id]):
            raise ValueError("Solidtime requires baseUrl, apiKey, organizationId, and memberId")

        return SolidtimeProvider(
            base_url=base_url,
            api_key=api_key,
            organization_id=organization_id,
            member_id=member_id,
        )

    raise ValueError(f"Unsupported backend: {backend}")


__all__ = [
    "create_provider",
    "TimeTrackingProvider",
    "TogglProvider",
    "SolidtimeProvider",
    "MockProvider",
    "RecordingMockProvider",
]
