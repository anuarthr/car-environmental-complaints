# ADR 0004: Stage the raw releases with dbt

- Status: accepted
- Date: 2026-11-17

## Context

raw holds every release of both datasets as text, including rows of any load that failed
halfway (ADR 0003). Profiling CAR's release of 2026-11-10 found no empty cells, but several
words that stand for a missing value, codes that mean yes and no, whitespace that splits one
value in two, columns that repeat others, and dates that contradict each other.

Three identities run dbt: a laptop, which develops against `dev`; pull requests, which may write
only `ci`; and the Pipeline workflow on `main`, which writes `prod` (ADR 0002). None of the
service accounts can create datasets.

dbt v2, a rewrite of dbt in Rust, became the default install in September 2026. The 1.x line,
in Python, is still maintained.

## Decision

- **dbt Core 1.12.** sqlfluff's dbt templater imports dbt Core's Python modules, which v2 no
  longer ships, and the 1.x line still gets releases.
- **One dataset per target.** `dev`, `ci` and `prod` each receive every model. Layers are told
  apart by prefix (`stg_`, later `int_` and `fct_`), not by dataset, because no account can
  create one.
- **Staging models are views.** They copy nothing, cost nothing to create and always show the
  latest load.
- **Staging reads the latest complete release.** A macro keeps rows whose `_dlt_load_id` is
  listed with status 0 in `_dlt_loads` and, of those, the latest `_release_at`.
- **One cleaning rule for every text column.** Non-breaking and repeated spaces collapse into
  one, and `Sin datos` and `No verificado` become null, in all columns, so a release that starts
  using them in another column is already covered.
- **Coded values are decoded, and their codes are guarded.** `SI` and `NO` become booleans, a
  resource marked `X` becomes true and CAR's on-time label becomes a boolean. An
  `accepted_values` test on each raw column decoded this way fails the build on a code staging
  does not know, which would otherwise become null without a word.
- **An unmarked resource is unknown, not "no".** Three in four complaints have no resource
  marked, and before 2014 almost none do, so `Sin datos` in those columns means the field was
  not filled in.
- **Spelling variants are left as published.** Veredas and records subseries vary in accents and
  case. Merging them would mean choosing a spelling, and DIVIPOLA shows that names differing only
  in an accent can be different places (CHIMA in Santander, CHIMÁ in Córdoba).
- **Redundant columns are dropped.** `a_o` and `mes` repeat the filing date and `color_estado`
  repeats `estado_respuesta`, with no disagreement in any row.
- **Recording errors are reported, not fixed.** Answers and deadlines dated before the filing
  date stay as published, and two singular tests report them with severity `warn`.
- **prod is built only in GitHub Actions.** An `on-run-start` hook stops any run against `prod`
  outside it, as the ingestion command keeps laptops out of `raw`.
- **Freshness follows the publisher.** It reads `_release_at`, when CAR published, not when the
  release was loaded, warns after 400 days and fails after 800. DIVIPOLA is not checked.

## Alternatives considered

| Alternative | Why not |
|---|---|
| dbt v2 | Two months old, and the SQL linter used here depends on dbt Core's Python modules. |
| A dataset per layer (`dev_staging`, `dev_marts`) | Needs an account that can create datasets in CI and in the pipeline, which ADR 0002 rules out. |
| Staging as tables | A copy of raw per target, rebuilt every week, for no gain at this size. |
| `safe_cast` for dates and ids | Hides a broken value as null. Every value parses today, so a strict cast fails the build if that ever changes. |
| Read `Sin datos` in the resource columns as false | The dashboard would say three in four complaints affect no resource. |
| Fix the dates that contradict each other | Nothing in the source says which date is wrong. |

## Consequences

- A new release changes staging the moment it is loaded, since staging is made of views. Tests
  run on it in the same workflow run.
- Analyses of the affected resource must use `theme`, which is filled in for every complaint,
  not the resource flags.
- A code CAR adds to a decoded column fails the Pipeline workflow until someone maps it.
- Pull requests share the `ci` dataset, so two of them building at the same time can overwrite
  each other's views. With one person merging, that is acceptable.
- Linting SQL needs Google credentials, because the dbt templater opens a BigQuery connection.
