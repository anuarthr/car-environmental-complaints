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
uv run sqlfluff lint transform  # lint the dbt SQL (needs Google credentials)
cd transform && uv run dbt build  # build and test the models in dev
uv run python -m calendar_build  # regenerate the holiday seed
```

## How work is done here

- **Tests first.** Write the failing test, run it and see it fail, then write the code. Python
  uses pytest; every dbt model with logic gets a dbt unit test before the model exists.
- **One branch and one pull request per milestone**, one commit per change. The repository
  owner reviews and merges. Never push to `main`.
- **Branch names and commit messages in English**, Conventional Commits style (`feat:`, `fix:`,
  `test:`, `docs:`, `build:`, `ci:`, `chore:`). The body explains what changed and why.
- **Comments explain business rules and decisions**, not language syntax.
- **Profile before staging.** Run the `profile-source` skill on a raw table before writing or
  changing its staging model, and after a new release.
- **Hooks enforce the basics** (`.claude/settings.json`): every edited Python file is formatted
  and linted with ruff, every edited dbt SQL file with sqlfluff, and a turn cannot end while the
  test suite fails or the dbt project does not parse. Fix the cause; never work around a hook.

## Data rules

- The source is published under CC BY-SA 4.0 and is anonymized. Never try to re-identify
  anyone, and keep the attribution in the README.
- Never commit raw extracts. Test fixtures are small, recorded API responses.
- Known quirks of the source, measured on 2026-11-10 and 2026-11-17 against the release CAR
  published on 2026-11-10. Re-measure before relying on them, since CAR may have published a
  new release:
  - CAR replaces the whole dataset when it publishes: all 75,240 rows of the current release
    were created on 2026-11-10, and the previous release came out on 2026-01-21. New releases
    are detected from `rowsUpdatedAt`, never by reloading blindly.
  - A release can rewrite the past: the one of 2026-11-10 added 6,289 complaints from 2025, and
    also changed complaints from earlier years.
  - There are no empty cells, but there are disguised nulls: `Sin datos` in `visita`,
    `finaliz_en`, `serie` and other columns, and `No verificado` in `municipio` and `vereda`
    (7,860 rows, new in the release of 2026-11-10).
  - "Not applicable" comes as `No Aplica` and as `[No Aplica]`, and `riesgo_salud_u_otros` uses
    `N.A` for a risk nobody assessed.
  - The five resource columns (`agua`, `aire`, `fauna`, `flora`, `suelo`) hold `X` or
    `Sin datos`, and three in four complaints have none marked (almost none before 2014), so an
    unmarked resource is unknown. `tema` names the resource for every complaint.
  - `a_o` and `mes` repeat the filing date, and `color_estado` repeats `estado_respuesta`.
  - `tema` contains non-breaking spaces (`\xa0`).
  - 198 answers are dated before their filing date, and 30 deadlines fall before it. One
    deadline (`item` 63277, filed on 2024-02-09) falls on 2026-12-01.
  - Only 26.7% of recorded deadlines fall 15 business days after filing; the rest cluster at 30
    and at 41 to 45, 60, 75 and 86 to 90, by a rule the data does not show. In 2020 and 2021
    most are 30, the term of Decreto Legislativo 491 de 2020. `estado_respuesta` measures
    against these recorded deadlines, not against the law.
  - Municipalities come as names without a department, so joining them to DIVIPOLA needs a
    curated mapping. DIVIPOLA repeats names across departments (four `BUENAVISTA`) and writes
    coordinates with a decimal comma.

## Cloud rules

- CI authenticates with Workload Identity Federation; local work uses
  `gcloud auth application-default login`. **Never create or commit service account keys.**
- Google Cloud project `car-complaints-elt`, BigQuery datasets `raw`, `dev`, `ci` and `prod` in
  `US`. The access model is in `docs/adr/0002-cloud-access.md`:
  - `ci-dbt` serves pull requests: it reads `raw` and writes `ci`.
  - `pipeline` serves the `production` environment, deployable only from `main`: it writes
    `raw` and `prod`.
  - Workflows read the ids from repository variables: `GCP_PROJECT_ID`, `GCP_WIF_PROVIDER`,
    `GCP_CI_SERVICE_ACCOUNT` and `GCP_PIPELINE_SERVICE_ACCOUNT`.
- Every cloud resource comes from `infra/bootstrap_gcp.sh`, which is safe to run again. Change
  the script and run it; never configure resources by hand in the console.
- On Windows, call `gcloud` and `bq` through the SDK's Python as the script header shows: the
  `.cmd` wrappers break arguments that contain spaces.
- Develop against the `dev` target. Never run against `prod` from a laptop.
- Keep `maximum_bytes_billed` in every dbt profile.
