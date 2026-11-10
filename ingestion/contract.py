"""Stop a run when a source publishes different columns from the ones the raw layer was built for.

The check reads the column list from the Socrata view metadata, so it runs before any row is
downloaded. It catches removed columns too, which a schema contract applied while loading cannot
see: a missing field would simply load as NULL.
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from typing import Any


class ColumnsChanged(RuntimeError):
    """The source publishes different columns from the ones the pipeline expects."""


def check_columns(metadata: Mapping[str, Any], expected: Iterable[str]) -> None:
    """Raise ColumnsChanged if the published columns differ from the expected ones.

    Order does not matter: rows are read by field name.
    """
    published = {column["fieldName"] for column in metadata["columns"]}
    expected = set(expected)
    added = sorted(published - expected)
    removed = sorted(expected - published)
    if added or removed:
        raise ColumnsChanged(
            f"The published columns changed (added: {', '.join(added) or 'none'}; "
            f"removed: {', '.join(removed) or 'none'}). Review the change and update the "
            "expected columns and the staging model before loading this release."
        )
