---
name: new-dbt-model
description: Add or change a dbt model in transform/ test first. Covers choosing the layer and grain, writing the dbt unit test before the model, seeing it fail against a typed stub, writing the model and its yml with data tests, reconciling the result with known figures, and the lint traps of this project. Use for any new staging, intermediate, fact, dimension or mart model, and for a change to a model's logic.
---

# Add a dbt model, test first

Work from `transform/` against the `dev` target. A staging model is preceded by the
`profile-source` skill; this skill starts once the source is understood.

## 1. Decide the layer, the name and the grain

| Layer | Prefix | Materialized | Holds |
|---|---|---|---|
| `models/staging/<source>/` | `stg_<source>__<entity>` | view | the latest complete release, typed and cleaned, one row per source row |
| `models/intermediate/<topic>/` | `int_<topic>__<what it adds>` | view | logic shared by several marts |
| `models/marts/` | `fct_`, `dim_`, `mart_` | table | what the dashboard and the analyses read |

Write the grain as one sentence before anything else ("one row per complaint", "one row per
filing month and regional office"). Every test below follows from it. A dimension earns its own
table only when it has attributes beyond its name; otherwise the column stays in the fact table.

## 2. Write the unit test first

Unit tests live next to the models in `_<dir>__unit_tests.yml`. Write one per rule the model
applies, each named `test_<model>_<what it guarantees>` and with a description that says why
the rule exists.

- Give every `ref()` the model reads, even with `rows: []`, or dbt cannot build the fixture.
  Seeds are given the same way.
- Columns left out of a given row are null, so each row only needs the columns the rule reads.
- Use real cases from the data when there is one (complaint 63277, Easter Sunday), and
  boundary rows on both sides of every cut.
- Expect only the columns the rule decides.

## 3. See it fail for the right reason

Create a stub with the model's name that reads every input and returns the expected columns as
typed nulls (`cast(null as int64) as complaints`). Then run:

```bash
uv run dbt test --select "<model>,test_type:unit"
```

Each test must fail with `expected → NULL` differences. A compilation error is not a red test:
fix the stub until the failure is about values. A test that passes against the stub proves
nothing; rewrite it.

## 4. Write the model

- CTEs that name each step; a final `select` that lists every column.
- Comments explain the business rule or the decision, never SQL.
- `left join` to a lookup whose key is tested unique, so no row is lost or repeated. An inner
  join that can drop rows needs a reason in a comment.
- In aggregations, aggregate first and join descriptive columns after.
- Marts hold counts, not rates: a rate is a ratio of sums. Rows that cannot be judged (an answer
  dated before filing) stay out of the denominator instead of counting as a success.

## 5. Document and test the data

In `_<dir>__models.yml`, describe the model with its grain and every column. Then add:

- `unique` and `not_null` on the key, or a model-level `unique` on the grain expression when it
  spans columns: `column_name: "format('%t|%t', col_a, col_b)"`.
- `relationships` from every foreign key to its dimension.
- `accepted_values` on coded columns, and `not_null` with `config: where:` when a column may be
  null only under a condition.
- A singular test in `tests/<layer>/` when rows must be conserved: the fact table against
  staging, each mart against the fact table.

## 6. Build and reconcile

```bash
uv run dbt build --select <model>
```

Unit tests now pass, and the data tests run on the real release. Passing tests are not enough:
query the model with `dbt show --inline` and compare its totals with figures already known
(row count, CAR's on-time count, the documented warnings). A different number means a join or a
filter changed the population.

## Traps seen in this project

- **The edit hook can fail on a unit test file** that names a model whose `.sql` does not exist
  yet: dbt cannot parse the project. Create every model file named in the yml before relying on
  the hook's lint result.
- **sqlfluff RF04** rejects keywords as column names (`month`, `quarter`, `year`, `resource`):
  use `calendar_month`, `resource_named` and the like.
- **sqlfluff RF02** wants every column qualified in a query with more than one table.
- **sqlfluff AM03** wants `asc` or `desc` on every `order by` column once one has it.
- **Scratch SQL written by PowerShell 5** starts with a byte order mark that BigQuery rejects
  ("Illegal input character \357"). Write scratch files with the Write tool or a bash heredoc.
- `dbt show` prints numbers with long float tails; round in the query when reading by eye.

## Finish

- A decision a reader would question (a dimension left out, a lookup curated by hand) goes in a
  new ADR under `docs/adr/`.
- Ask the `model-reviewer` subagent to review the change before opening the pull request.
- One commit per change, in English, Conventional Commits style.
