"""A dlt source that loads datasets from datos.gov.co one release at a time.

Each dataset becomes a raw table where every release is appended with its release timestamp.
A run downloads a dataset only when the publisher released a newer version, checks its columns
before downloading, and fails unless every row the source reports has arrived.
"""

from __future__ import annotations

import logging
from collections.abc import Iterator
from datetime import datetime
from typing import Any

import dlt
from dlt.sources import DltResource
from dlt.sources.helpers.rest_client import RESTClient
from dlt.sources.helpers.rest_client.paginators import OffsetPaginator

from ingestion.contract import check_columns
from ingestion.datasets import DATASETS, Dataset
from ingestion.release import is_new_release, released_at

BASE_URL = "https://www.datos.gov.co"
USER_AGENT = (
    "car-environmental-complaints (+https://github.com/anuarthr/car-environmental-complaints)"
)
# The SODA 2.0 endpoints return at most 50,000 rows per request.
PAGE_SIZE = 50_000
RELEASE_COLUMN = "_release_at"
STATE_KEY = "released_at"

logger = logging.getLogger(__name__)


class IncompleteDownload(RuntimeError):
    """The number of rows received differs from the number the source reports."""


@dlt.source(name="datos_gov_co")
def datos_gov_co(page_size: int = PAGE_SIZE) -> list[DltResource]:
    """Return one resource per dataset in DATASETS."""
    client = RESTClient(base_url=BASE_URL, headers={"User-Agent": USER_AGENT})
    return [_release_resource(client, dataset, page_size) for dataset in DATASETS]


def _release_resource(client: RESTClient, dataset: Dataset, page_size: int) -> DltResource:
    # Every published field lands as text, exactly as the API serves it. Left to infer, dlt would
    # turn ISO-looking dates into timestamps, and a numeric type would drop the leading zero of
    # DANE codes. Staging owns the typing.
    columns: dict[str, Any] = {name: {"data_type": "text"} for name in dataset.columns}
    columns[RELEASE_COLUMN] = {"data_type": "timestamp", "nullable": False}

    @dlt.resource(
        name=dataset.table,
        # Each release is kept next to the previous ones; staging selects the latest.
        write_disposition="append",
        columns=columns,
        # Rows may not bring fields or types the raw table was not built for.
        schema_contract={"columns": "freeze", "data_type": "freeze"},
    )
    def release_rows() -> Iterator[list[dict[str, Any]]]:
        metadata = _get_json(client, f"/api/views/{dataset.id}.json")
        published = released_at(metadata)
        state = dlt.current.resource_state()
        last_loaded = datetime.fromisoformat(state[STATE_KEY]) if STATE_KEY in state else None
        if not is_new_release(published, last_loaded):
            logger.info("%s: release %s is already loaded", dataset.id, published.isoformat())
            return

        check_columns(metadata, dataset.columns)
        expected = int(
            _get_json(client, f"/resource/{dataset.id}.json", {"$select": "count(*)"})[0]["count"]
        )

        received = 0
        paginator = OffsetPaginator(
            limit=page_size, offset_param="$offset", limit_param="$limit", total_path=None
        )
        # Ordering by Socrata's internal row id keeps pages from overlapping or skipping rows.
        pages = client.paginate(
            f"/resource/{dataset.id}.json", params={"$order": ":id"}, paginator=paginator
        )
        for page in pages:
            received += len(page)
            yield [{**row, RELEASE_COLUMN: published} for row in page]

        if received != expected:
            raise IncompleteDownload(
                f"{dataset.id}: received {received} rows, but the source reports {expected}"
            )
        # Saved only once every row has arrived, so a failed run leaves the release to the next.
        state[STATE_KEY] = published.isoformat()
        logger.info("%s: release %s, %d rows", dataset.id, published.isoformat(), received)

    return release_rows


def _get_json(client: RESTClient, path: str, params: dict[str, str] | None = None) -> Any:
    response = client.get(path, params=params)
    response.raise_for_status()
    return response.json()
