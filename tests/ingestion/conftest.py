"""A fake datos.gov.co that serves recorded responses, so the pipeline runs without network.

The fixtures were recorded on 2026-11-09: the first three rows of each dataset in Socrata's
stable order (`$order=:id`), and the view metadata trimmed to the fields the pipeline reads.
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlsplit

import dlt
import pytest

from ingestion.datasets import DATASETS

FIXTURES = Path(__file__).parent / "fixtures"
ONE_YEAR = 365 * 24 * 3600


def load_fixture(dataset_id: str, name: str) -> Any:
    return json.loads((FIXTURES / dataset_id / f"{name}.json").read_text(encoding="utf-8"))


@dataclass
class FakeDataset:
    """What the fake API publishes for one dataset. Tests change it to simulate the publisher."""

    metadata: dict[str, Any]
    rows: list[dict[str, Any]]
    # Overrides the answer to count(*), to simulate a download that lost rows.
    reported_count: int | None = None
    row_requests: int = 0

    @classmethod
    def recorded(cls, dataset_id: str) -> FakeDataset:
        return cls(load_fixture(dataset_id, "metadata"), load_fixture(dataset_id, "rows"))

    def publish_new_release(self) -> None:
        self.metadata["rowsUpdatedAt"] += ONE_YEAR


class FakeDatosGovCo:
    """Answers the three calls the pipeline makes: view metadata, count(*) and pages of rows."""

    def __init__(self, requests_mock: Any) -> None:
        # Serves a recorded release for every dataset the pipeline declares.
        self.datasets = {dataset.id: FakeDataset.recorded(dataset.id) for dataset in DATASETS}
        requests_mock.get(
            re.compile(r"https://www\.datos\.gov\.co/api/views/[\w-]+\.json"), json=self._metadata
        )
        requests_mock.get(
            re.compile(r"https://www\.datos\.gov\.co/resource/[\w-]+\.json"), json=self._resource
        )

    def __getitem__(self, dataset_id: str) -> FakeDataset:
        return self.datasets[dataset_id]

    def _dataset(self, request: Any) -> FakeDataset:
        dataset_id = Path(urlsplit(request.url).path).stem
        return self.datasets[dataset_id]

    def _metadata(self, request: Any, context: Any) -> dict[str, Any]:
        return self._dataset(request).metadata

    def _resource(self, request: Any, context: Any) -> list[dict[str, Any]]:
        dataset = self._dataset(request)
        params = {key: values[0] for key, values in parse_qs(urlsplit(request.url).query).items()}
        if params.get("$select") == "count(*)":
            count = len(dataset.rows) if dataset.reported_count is None else dataset.reported_count
            return [{"count": str(count)}]
        assert params.get("$order") == ":id", "pages need a stable order or rows can be skipped"
        dataset.row_requests += 1
        offset, limit = int(params.get("$offset", 0)), int(params["$limit"])
        return dataset.rows[offset : offset + limit]


@pytest.fixture
def api(requests_mock: Any) -> FakeDatosGovCo:
    return FakeDatosGovCo(requests_mock)


@pytest.fixture
def new_machine(tmp_path: Path) -> Callable[[str], dlt.Pipeline]:
    """Build the pipeline on a machine with its own local state, against a shared warehouse."""
    warehouse = str(tmp_path / "warehouse.duckdb")

    def build(machine: str) -> dlt.Pipeline:
        return dlt.pipeline(
            pipeline_name="test_datos_gov_co",
            destination=dlt.destinations.duckdb(warehouse),
            dataset_name="raw",
            pipelines_dir=str(tmp_path / machine),
        )

    return build


@pytest.fixture
def pipeline(new_machine: Callable[[str], dlt.Pipeline]) -> dlt.Pipeline:
    return new_machine("laptop")
