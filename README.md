# CAR Environmental Complaints

End-to-end ELT pipeline and analysis of the environmental complaints filed with the
Corporación Autónoma Regional de Cundinamarca (CAR), Colombia. The release CAR published on
2026-11-10 holds **75,240 complaints** filed from 2009 to 2025.

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
uv run sqlfluff lint transform
```

Tests run against recorded API responses and a local DuckDB file, so they need neither the
network nor Google Cloud. They also check that the dbt project parses. Linting SQL does need
Google credentials, because sqlfluff's dbt templater opens a BigQuery connection.

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

## Transformation

`transform/` is a dbt project. Staging reads the latest complete release of each source, gives
the columns English names and types, and cleans what profiling found: words that stand for a
missing value become null, yes and no codes become booleans, and stray spaces go. The decisions
are in [ADR 0004](docs/adr/0004-staging.md).

| Who runs it | Command, from `transform/` | Builds into |
|---|---|---|
| You, on a laptop | `uv run dbt build` | `dev` |
| The [CI workflow](.github/workflows/ci.yml), on each pull request | `uv run dbt build --target ci` | `ci` |
| The Pipeline workflow, after each load | `uv run dbt build --target prod` | `prod` |

Every query is capped at 1 GB billed, and a run against `prod` outside GitHub Actions stops
before it starts. Unit tests check the cleaning rules on a few invented rows; data tests check
the real ones. Two tests warn about records CAR dated inconsistently, which staging keeps as
published: in the release of 2026-11-10, 198 answers and 30 deadlines come before their filing
date.

## Data source and license

- **Quejas Ambientales CAR Cundinamarca**, published by CAR on
  [datos.gov.co](https://www.datos.gov.co/d/5ddb-j9e9) under
  [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The source is anonymized.
- **DIVIPOLA municipality codes**, published by DANE on
  [datos.gov.co](https://www.datos.gov.co/d/gdxc-w37w).

Derived datasets are shared under the same CC BY-SA 4.0 license. The code is under the
[MIT license](LICENSE).
