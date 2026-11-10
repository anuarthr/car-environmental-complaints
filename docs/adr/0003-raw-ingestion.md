# ADR 0003: Load the raw layer one release at a time

- Status: accepted
- Date: 2026-11-10

## Context

CAR publishes its complaints on datos.gov.co by replacing the whole dataset, months apart: the
last two releases came out on 2026-01-21 and 2026-11-10, and every row of a release is created
the day it is published. A release can also change complaints from earlier years. DANE's
DIVIPOLA table changes rarely too.
The Socrata API serves every field as text, strips accents from field names
(`fecha_radicaci_n`, `a_o`) and returns at most 50,000 rows per request.

A weekly GitHub Actions job has to load both datasets into BigQuery without duplicating a
release, without losing one and without hiding a change in the source. The runner starts empty
on every run, and the `pipeline` service account can write tables in `raw` but cannot create
datasets (ADR 0002).

## Decision

- **A release is the unit of loading.** It is identified by the view's `rowsUpdatedAt`, which
  moves only when the rows change. `viewLastModified` was rejected because it also moves when
  the publisher edits the description or the tags. A run downloads a dataset only when its
  `rowsUpdatedAt` is newer than the last one loaded, and fails if it is older.
- **Each release is appended**, stamped with its release time in `_release_at`. Staging selects
  the latest release.
- **The last loaded release lives in dlt's state, inside the warehouse.** dlt saves its state
  with every load in `raw._dlt_pipeline_state` and restores it from there when the runner has
  none. The release is written to the state only after every row has arrived.
- **Raw is text.** Every published field is declared as text, and `_release_at` as a timestamp.
  Typing happens in staging.
- **Two checks against a changing source.** Before downloading, the run compares the columns
  in the view metadata with the expected ones and stops on any column added or removed. While
  loading, a dlt schema contract (`columns` and `data_type` frozen) rejects anything else.
- **A download is complete or it fails.** Pages are read with `$limit` and `$offset`, ordered by
  Socrata's row id `:id` so they neither overlap nor skip rows, and the run fails unless the
  rows received match the `count(*)` the API reports.
- **Laptops never write raw.** The ingestion command accepts only `dev` and `raw`, and defaults
  to `dev`. Only the Pipeline workflow on `main`, acting as the `pipeline` service account,
  writes `raw`.

## Alternatives considered

| Alternative | Why not |
|---|---|
| `replace` on every new release | Keeps only the latest release, so the history of releases is lost, and a week that skips the download would leave the table empty. |
| `merge` on a key | Keeps one version of each row, so earlier releases are lost, and dlt needs a `raw_staging` dataset that the `pipeline` account cannot create. |
| Detect a new release by hashing rows or comparing counts | Needs the whole dataset every week. `rowsUpdatedAt` answers the same question with one metadata request. |
| Keep dlt's state in the GitHub Actions cache or in an artifact | Caches unused for 7 days are evicted and artifacts expire, so the state could drift from what the warehouse holds. |
| Let dlt infer the column types | It turns ISO-looking text into timestamps, and a numeric type would drop the leading zero of DANE codes. |

## Consequences

- `raw` grows by a full copy of the dataset with every release, about 75,000 complaint rows
  today. Keeping them all costs almost nothing and lets the project compare releases.
- A load that fails halfway can leave rows in a data table, and the next run loads that release
  again, because dlt restores state only from loads it marked complete in `_dlt_loads`. Staging
  must therefore keep only rows whose `_dlt_load_id` is complete in `_dlt_loads`, and of those
  the latest `_release_at`.
- A change in the source's columns fails the run before any row is downloaded. Someone has to
  review it, update `ingestion/datasets.py` and the staging model, and run the pipeline again.
- GitHub disables scheduled workflows in public repositories after 60 days without activity.
  CAR's last two releases came about ten months apart, so after a quiet spell in the repository,
  check that the Pipeline workflow is still enabled (`gh workflow enable pipeline.yml`), or
  start it by hand.
