---
name: profile-source
description: Profile a table of the raw BigQuery dataset before writing or changing its staging model, or after a source publishes a new release. Measures releases and loads, keys, disguised nulls, spelling variants, whitespace, value formats, ranges and coherence between columns, then turns each finding into a staging decision and a test.
---

# Profile a raw source

Work from `transform/` against the `dev` target. The queries read raw through `source()`, so the
table must be declared in a `_<source>__sources.yml`, and they inherit the 1 GB cap of
`profiles.yml`. BigQuery bills at least 10 MB for each table a query reads: put many checks in
one query instead of running many small ones.

Every query looks only at the rows staging reads: loads dlt finished (`status = 0` in
`_dlt_loads`) of the latest `_release_at`.

Never write query results into the repository. Raw extracts stay out of git; save them in the
session's scratch directory.

## 1. Releases and loads

```bash
uv run dbt show --quiet --limit 50 --vars '{source: car, table: car_complaints}' \
  --inline "$(cat ../.claude/skills/profile-source/releases.sql)"
```

Expect one complete load per release. A load whose status is empty never finished, and staging
ignores its rows.

## 2. Every text column in one scan

```bash
uv run dbt show --quiet --output json --limit 200 --vars '{source: car, table: car_complaints}' \
  --inline "$(cat ../.claude/skills/profile-source/column_profile.sql)" > "$SCRATCH/profile.json"
```

Use `--output json`: the table output cuts long values. Read each field like this:

| Field | Read it as |
|---|---|
| `row_count` equal to `distinct_values` | a candidate key |
| `distinct_plain` below `distinct_values` | spellings of one value: see `variant_groups` |
| `markers`, `marker_rows` | candidate disguised nulls, matched after removing punctuation |
| `nbsp_rows`, `repeated_space_rows`, `untrimmed_rows` | whitespace staging must normalize |
| `share_integer`, `share_decimal`, `share_iso_date`, `share_yes_no` | the type to cast to; below 1.0, look at the rest of the values |
| `top_values` | complete when `distinct_values` is 15 or fewer: candidates for `accepted_values` |

A marker is a candidate, not a verdict. `X` can mean yes, and `No Aplica` can be a real
category. Read the values of every flagged column before deciding.

A variant group is a candidate too. Values that differ only in an accent can be different
things: DIVIPOLA has CHIMA (Santander) and CHIMÁ (Córdoba). Do not merge accents or case
automatically.

## 3. Formats, ranges and coherence

Write one query for the table, in the scratch directory, that starts from the same latest
complete release and answers, with `countif`:

- **Formats.** Parse with `safe.` functions and count what fails. A strict `cast` in staging is
  safe only when that count is 0, and then it should stay strict, so a broken value fails the
  build.
- **Ranges.** The minimum and maximum of every parsed date and number, and how many dates fall
  after the release.
- **Redundant columns.** A column derived from another one (a year from a date, a color from a
  label): count the rows where they disagree. Zero means staging can drop it.
- **Order of events.** Count rows where a later event is dated before an earlier one.
- **What a marker means.** Before reading a marker as "no" or as "unknown", look at its share by
  year or by category. A marker that covers most rows, or whole years, means the field was not
  recorded.

## 4. Calibrate

Compare the figures that were measured before (the quirks in `CLAUDE.md`, the last profile)
with what the queries return. If they match, trust the new figures. If they do not, either the
query or the release changed: check `rowsUpdatedAt` on datos.gov.co first.

## 5. Decide

Finish with one table: column, finding, count, what staging does with it, and the test that
keeps watching it. State the release the counts were measured on, since a new release can change
them.
