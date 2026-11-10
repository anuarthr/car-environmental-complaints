"""Each run loads every row of a new release into raw, exactly as published, and nothing else."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import dlt
import pytest
from dlt.common.schema.exceptions import DataValidationError
from dlt.pipeline.exceptions import PipelineStepFailed

from ingestion.contract import ColumnsChanged
from ingestion.datasets import CAR_COMPLAINTS, DIVIPOLA_MUNICIPALITIES
from ingestion.release import released_at
from ingestion.socrata import IncompleteDownload, datos_gov_co

CAR = CAR_COMPLAINTS.id
DIVIPOLA = DIVIPOLA_MUNICIPALITIES.id

# Three recorded rows per dataset, read two at a time, so every load needs several pages.
PAGE_SIZE = 2


def run(pipeline: dlt.Pipeline) -> None:
    pipeline.run(datos_gov_co(page_size=PAGE_SIZE))


def query(pipeline: dlt.Pipeline, sql: str, table: str) -> list[tuple[Any, ...]]:
    with pipeline.sql_client() as client:
        return client.execute_sql(sql.format(table=client.make_qualified_table_name(table)))


def rows_per_release(pipeline: dlt.Pipeline, table: str) -> dict[datetime, int]:
    counts = query(
        pipeline, "SELECT epoch(_release_at)::BIGINT, count(*) FROM {table} GROUP BY 1", table
    )
    return {datetime.fromtimestamp(seconds, UTC): n for seconds, n in counts}


def caused_by(error: BaseException, kind: type[BaseException]) -> bool:
    """Whether kind appears anywhere in the chain of errors that dlt wraps around the original."""
    current: BaseException | None = error
    while current is not None:
        if isinstance(current, kind):
            return True
        current = current.__cause__ or current.__context__
    return False


def test_the_first_run_loads_every_row_of_both_datasets(pipeline, api):
    run(pipeline)

    assert rows_per_release(pipeline, CAR_COMPLAINTS.table) == {released_at(api[CAR].metadata): 3}
    assert rows_per_release(pipeline, DIVIPOLA_MUNICIPALITIES.table) == {
        released_at(api[DIVIPOLA].metadata): 3
    }


def test_values_land_exactly_as_published(pipeline, api):
    run(pipeline)

    # Typed columns would turn the filing date into a timestamp and drop the leading zero of
    # DANE codes, which breaks joins. Staging owns the typing.
    car_columns = pipeline.default_schema.get_table_columns(CAR_COMPLAINTS.table)
    assert {
        name: car_columns[name]["data_type"] for name in CAR_COMPLAINTS.columns
    } == dict.fromkeys(CAR_COMPLAINTS.columns, "text")
    assert query(
        pipeline, "SELECT fecha_radicaci_n FROM {table} WHERE item = '1'", CAR_COMPLAINTS.table
    ) == [("2009-01-02T00:00:00.000",)]
    assert query(
        pipeline,
        "SELECT cod_mpio, longitud FROM {table} WHERE nom_mpio = 'MEDELLÍN'",
        DIVIPOLA_MUNICIPALITIES.table,
    ) == [("05001", "-75,581775")]


def test_a_second_run_without_a_new_release_downloads_and_loads_nothing(pipeline, api):
    run(pipeline)
    requests_after_first_run = api[CAR].row_requests

    run(pipeline)

    assert api[CAR].row_requests == requests_after_first_run
    assert rows_per_release(pipeline, CAR_COMPLAINTS.table) == {released_at(api[CAR].metadata): 3}


def test_a_fresh_machine_takes_the_last_release_from_the_warehouse(pipeline, new_machine, api):
    run(pipeline)
    requests_after_first_run = api[CAR].row_requests

    # GitHub Actions starts every run on an empty machine, so only the warehouse remembers.
    run(new_machine("github_actions"))

    assert api[CAR].row_requests == requests_after_first_run
    assert rows_per_release(pipeline, CAR_COMPLAINTS.table) == {released_at(api[CAR].metadata): 3}


def test_a_new_release_is_appended_next_to_the_previous_one(pipeline, api):
    run(pipeline)
    first_release = released_at(api[CAR].metadata)
    api[CAR].publish_new_release()

    run(pipeline)

    assert rows_per_release(pipeline, CAR_COMPLAINTS.table) == {
        first_release: 3,
        released_at(api[CAR].metadata): 3,
    }
    assert rows_per_release(pipeline, DIVIPOLA_MUNICIPALITIES.table) == {
        released_at(api[DIVIPOLA].metadata): 3
    }


def test_changed_columns_stop_the_run_before_any_row_is_downloaded(pipeline, api):
    api[CAR].metadata["columns"].append({"fieldName": "vereda_nueva", "dataTypeName": "text"})

    with pytest.raises(PipelineStepFailed) as failure:
        run(pipeline)

    assert caused_by(failure.value, ColumnsChanged)
    assert api[CAR].row_requests == 0


def test_an_unexpected_field_in_the_rows_of_a_new_release_stops_the_load(pipeline, api):
    run(pipeline)
    first_release = released_at(api[CAR].metadata)
    api[CAR].publish_new_release()
    api[CAR].rows[0]["campo_sorpresa"] = "x"

    with pytest.raises(PipelineStepFailed) as failure:
        run(pipeline)

    assert caused_by(failure.value, DataValidationError)
    assert rows_per_release(pipeline, CAR_COMPLAINTS.table) == {first_release: 3}


def test_a_truncated_download_fails_and_the_next_run_loads_it_once(pipeline, api):
    api[CAR].reported_count = 4

    with pytest.raises(PipelineStepFailed) as failure:
        run(pipeline)
    assert caused_by(failure.value, IncompleteDownload)

    api[CAR].reported_count = None
    run(pipeline)

    assert rows_per_release(pipeline, CAR_COMPLAINTS.table) == {released_at(api[CAR].metadata): 3}
