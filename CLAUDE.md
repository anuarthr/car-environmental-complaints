# CLAUDE.md

Guide for Claude Code in this repository.

## What this is

A public portfolio project: an ELT pipeline and analysis of the environmental complaints filed
with CAR Cundinamarca (datos.gov.co `5ddb-j9e9`). DANE's DIVIPOLA municipality codes
(`gdxc-w37w`) are the only other source, used as a reference table.

The scope is closed: no other entities, no free text, no population rates. The questions the
project answers are listed in the README.

Stack: dlt (extract and load) into BigQuery, dbt (transform and test), Looker Studio
(dashboard), orchestrated by GitHub Actions. Python 3.12 managed by uv. The reasons are in
`docs/adr/0001-stack.md`.

## Commands

```bash
uv sync --locked             # install the locked environment
uv run pytest                # run the test suite
uv run ruff format .         # format
uv run ruff check .          # lint
```

## How work is done here

- **Tests first.** Write the failing test, run it and see it fail, then write the code. Python
  uses pytest; every dbt model with logic gets a dbt unit test before the model exists.
- **One branch and one pull request per milestone**, one commit per change. The repository
  owner reviews and merges. Never push to `main`.
- **Branch names and commit messages in English**, Conventional Commits style (`feat:`, `fix:`,
  `test:`, `docs:`, `build:`, `ci:`, `chore:`). The body explains what changed and why.
- **Comments explain business rules and decisions**, not language syntax.
- **Hooks enforce the basics** (`.claude/settings.json`): every edited Python file is formatted
  and linted with ruff, and a turn cannot end while the test suite fails. Fix the cause; never
  work around a hook.

## Data rules

- The source is published under CC BY-SA 4.0 and is anonymized. Never try to re-identify
  anyone, and keep the attribution in the README.
- Never commit raw extracts. Test fixtures are small, recorded API responses.
- Known quirks of the source, measured on 2026-11-05. Re-measure before relying on them, since
  CAR may have published a new release:
  - CAR publishes once a year and replaces the whole dataset: every row was created on
    2026-01-21. New releases are detected from `rowsUpdatedAt`, never by reloading blindly.
  - There are no empty cells, but there are disguised nulls: `Sin datos` in `visita`,
    `finaliz_en`, `serie` and other columns.
  - `tema` contains non-breaking spaces (`\xa0`).
  - 196 answers are dated before their filing date, and 30 deadlines fall before it.
  - Municipalities come as names without a department, so joining them to DIVIPOLA needs a
    curated mapping.

## Cloud rules

- CI authenticates with Workload Identity Federation; local work uses
  `gcloud auth application-default login`. **Never create or commit service account keys.**
- Develop against the `dev` target. Never run against `prod` from a laptop.
- Keep `maximum_bytes_billed` in every dbt profile.
