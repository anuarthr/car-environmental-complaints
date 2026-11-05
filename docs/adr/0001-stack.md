# ADR 0001: Stack for the pipeline

- Status: accepted
- Date: 2026-11-05

## Context

The project loads one public dataset (68,948 rows, published once a year by replacing it
entirely) and one reference table, models them and publishes a dashboard. It is a public
portfolio project: anyone must be able to read, run and verify it, and it should cost nothing
to operate.

## Decision

| Concern | Choice | Alternatives considered |
|---|---|---|
| Extract and load | dlt | Airbyte, Stitch, a hand-written loader |
| Warehouse | BigQuery with billing enabled, a budget alert and `maximum_bytes_billed` | BigQuery sandbox, DuckDB |
| Transform and test | dbt Core with the BigQuery adapter | Plain SQL scripts, Dataform |
| Orchestration and CI | GitHub Actions on a weekly schedule | Airflow, Dagster, Prefect |
| Dashboard | Looker Studio | Power BI |
| Python tooling | uv, pytest, ruff | pip with requirements files, Poetry |
| Cloud authentication | Workload Identity Federation | Service account keys |

## Rationale

- **dlt** is extract and load as a Python library. It runs inside a GitHub Actions job, infers
  and versions the schema, can freeze it with a schema contract and keeps state between runs.
  Airbyte needs a server running all the time, which is heavy for one source and hard for a
  reader to reproduce. Stitch is a paid service.
- **BigQuery** is a common warehouse in data teams, and its free tier covers this volume. The
  sandbox was rejected because it does not allow DML, which rules out incremental models and
  release history, and it expires tables after 60 days.
- **dbt** keeps every transformation in versioned SQL with tests, documentation and lineage.
- **GitHub Actions** is enough to orchestrate one weekly run of one source. A dedicated
  orchestrator would add infrastructure without adding value at this size.
- **Looker Studio** connects to BigQuery natively and can be shared with a public link, so a
  reader opens the dashboard without installing anything. Publishing Power BI to the web needs
  a work or school account.
- **Workload Identity Federation** gives CI short-lived credentials, so there is no long-lived
  key that could leak from a public repository.

## Consequences

- Billing must stay under control: a budget alert, `maximum_bytes_billed` in the dbt profiles
  and no scheduled job more often than weekly.
- Each yearly release is appended to the raw layer with its release timestamp, so history
  accumulates from the first load onward.
- Running the pipeline end to end needs a Google Cloud project. Tests and linting do not.
