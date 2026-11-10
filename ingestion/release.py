"""Decide whether a dataset on datos.gov.co holds a release the pipeline has not loaded yet.

CAR publishes its complaints by replacing the whole dataset, months apart, so reloading on every
run would only duplicate rows. A run loads a dataset when its release timestamp moved forward.
"""

from __future__ import annotations

from collections.abc import Mapping
from datetime import UTC, datetime
from typing import Any


class ReleaseWentBackwards(RuntimeError):
    """The source reports an older release than the one already loaded."""


def released_at(metadata: Mapping[str, Any]) -> datetime:
    """Return when the dataset's rows were last published, from its Socrata view metadata."""
    # rowsUpdatedAt moves only when the rows change. viewLastModified also moves when the
    # publisher edits the description or the tags, so it would reload unchanged data.
    if "rowsUpdatedAt" not in metadata:
        raise ValueError("The view metadata has no rowsUpdatedAt, so the release cannot be dated")
    return datetime.fromtimestamp(metadata["rowsUpdatedAt"], tz=UTC)


def is_new_release(published: datetime, last_loaded: datetime | None) -> bool:
    """Return whether the published release is newer than the last one loaded."""
    if last_loaded is None:
        return True
    if published < last_loaded:
        # Release timestamps only move forward. An older one means the saved state or the source
        # is wrong, and skipping the run quietly would hide it.
        raise ReleaseWentBackwards(
            f"The source reports a release from {published.isoformat()}, older than the one "
            f"already loaded from {last_loaded.isoformat()}"
        )
    return published > last_loaded
