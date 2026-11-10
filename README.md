# CAR Environmental Complaints

End-to-end ELT pipeline and analysis of the **68,948 environmental complaints** filed with the
Corporación Autónoma Regional de Cundinamarca (CAR), Colombia, between 2009 and 2024.

> Work in progress. The project is being built in public, one milestone at a time.

## Questions this project answers

1. How long does CAR take to answer a complaint, and how has that changed since 2009?
2. Where does it miss the legal deadline most often: by regional office, channel, theme or type of filer?
3. Do partial answers inflate the on-time rate?
4. Do the recorded deadlines match the legal term of 15 business days?
5. Where are complaints concentrated, and which natural resource do they concern?

## Stack

| Layer | Tool |
|---|---|
| Extract and load | [dlt](https://dlthub.com/) from the Socrata API of datos.gov.co |
| Warehouse | Google BigQuery |
| Transform and test | dbt |
| Orchestration and CI | GitHub Actions |
| Dashboard | Looker Studio |

## Development

Requires [uv](https://docs.astral.sh/uv/). It installs Python 3.12 and the locked dependencies.

```bash
uv sync --locked
uv run pytest
uv run ruff format --check . && uv run ruff check .
```

Tests run against recorded API responses and a local DuckDB file, so they need neither the
network nor Google Cloud.

## Ingestion

`ingestion/` loads both datasets into BigQuery with dlt. A run checks each dataset's release
timestamp on datos.gov.co and downloads it only when a new release is out. Each release is
appended to the raw layer next to the earlier ones, so a run without a new release loads
nothing. The reasons are in [ADR 0003](docs/adr/0003-raw-ingestion.md).

| Who runs it | Command | Loads into |
|---|---|---|
| You, on a laptop | `uv run python -m ingestion.pipeline` | `dev` |
| The [Pipeline workflow](.github/workflows/pipeline.yml), on Mondays and on demand, from `main` only | `uv run python -m ingestion.pipeline --dataset raw` | `raw` |

A local run uses your Application Default Credentials (`gcloud auth application-default login`).
To load into your own Google Cloud project, change `project_id` in `.dlt/config.toml`; dlt
creates the dataset if it does not exist.

## Data source and license

- **Quejas Ambientales CAR Cundinamarca**, published by CAR on
  [datos.gov.co](https://www.datos.gov.co/d/5ddb-j9e9) under
  [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The source is anonymized.
- **DIVIPOLA municipality codes**, published by DANE on
  [datos.gov.co](https://www.datos.gov.co/d/gdxc-w37w).

Derived datasets are shared under the same CC BY-SA 4.0 license. The code is under the
[MIT license](LICENSE).
