"""The command line loads into dev unless told otherwise and keeps each dataset's state apart."""

from pathlib import Path

import dlt
import pytest

from ingestion.datasets import CAR_COMPLAINTS
from ingestion.pipeline import build_pipeline, parse_args
from ingestion.socrata import datos_gov_co


def test_a_local_run_loads_into_dev():
    assert parse_args([]).dataset == "dev"


def test_the_scheduled_run_loads_into_raw():
    assert parse_args(["--dataset", "raw"]).dataset == "raw"


@pytest.mark.parametrize("dataset", ["prod", "ci"])
def test_datasets_that_hold_dbt_models_are_refused(dataset):
    with pytest.raises(SystemExit):
        parse_args(["--dataset", dataset])


def test_switching_datasets_on_one_machine_neither_skips_nor_repeats_a_load(api, tmp_path: Path):
    # The release saved by a run into one dataset must not decide what another one receives.
    destination = dlt.destinations.duckdb(str(tmp_path / "warehouse.duckdb"))
    laptop = str(tmp_path / "laptop")

    for dataset in ("dev", "raw", "dev"):
        build_pipeline(dataset, destination, pipelines_dir=laptop).run(datos_gov_co(page_size=2))

    for dataset in ("dev", "raw"):
        pipeline = build_pipeline(dataset, destination, pipelines_dir=laptop)
        with pipeline.sql_client() as client:
            table = client.make_qualified_table_name(CAR_COMPLAINTS.table)
            assert client.execute_sql(f"SELECT count(*) FROM {table}") == [(3,)], dataset
