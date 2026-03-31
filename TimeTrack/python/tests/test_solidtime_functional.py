"""Functional tests for Solidtime provider - hits real API."""

import pytest

from timetrack.config import load_config
from timetrack.providers.solidtime import get_solidtime_memberships


def _get_solidtime_config() -> dict:
    """Get solidtime source config, skip if not configured."""
    config = load_config()
    source = config.get("sources", {}).get("solidtime", {})
    if not source.get("baseUrl") or not source.get("apiKey"):
        pytest.skip("Solidtime not configured (missing baseUrl or apiKey)")
    if "<your-" in str(source):
        pytest.skip("Solidtime config has placeholder values")
    return source


def test_get_memberships():
    """Fetch and print organization memberships."""
    source = _get_solidtime_config()

    memberships = get_solidtime_memberships(source["baseUrl"], source["apiKey"])

    print(f"\nMemberships ({len(memberships)}):")
    for m in memberships:
        print(f"  {m['organizationName']}  orgId={m['organizationId']}  memberId={m['memberId']}")

    assert len(memberships) > 0, "Expected at least one membership"
    assert all("organizationId" in m and "memberId" in m for m in memberships)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
