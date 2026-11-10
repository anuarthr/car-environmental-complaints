"""Load the datos.gov.co datasets into a BigQuery dataset.

uv run python -m ingestion.pipeline                 # local work: loads into dev
uv run python -m ingestion.pipeline --dataset raw   # the scheduled workflow
"""

from __future__ import annotations

import argparse
import logging
import sys
from collections.abc import Sequence

import dlt
from dlt.common.destination import TDestinationReferenceArg

from ingestion.socrata import datos_gov_co

# Raw data only lands in these datasets. prod and ci hold dbt models, and dev is where a laptop
# rehearses a load without touching the raw layer that CI and production read.
TARGET_DATASETS = ("dev", "raw")


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dataset",
        choices=TARGET_DATASETS,
        default="dev",
        help="BigQuery dataset to load into (default: dev; only the scheduled workflow uses raw)",
    )
    return parser.parse_args(argv)


def build_pipeline(
    dataset: str,
    destination: TDestinationReferenceArg = "bigquery",
    pipelines_dir: str | None = None,
) -> dlt.Pipeline:
    return dlt.pipeline(
        pipeline_name="datos_gov_co",
        destination=destination,
        dataset_name=dataset,
        pipelines_dir=pipelines_dir,
    )


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
    load_info = build_pipeline(args.dataset).run(datos_gov_co())
    print(load_info)
    return 0


if __name__ == "__main__":
    sys.exit(main())
