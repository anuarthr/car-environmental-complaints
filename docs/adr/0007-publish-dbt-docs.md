# ADR 0007: Publish the dbt docs from prod after each pipeline run

- Status: accepted
- Date: 2026-11-23

## Context

dbt documents every model, column and test, and draws the lineage from the sources to the
marts. Generating that site needs the project's code and, for the catalog of column types and
table sizes, a connection to the warehouse. The site is worth publishing next to the
dashboard, so a reader can see how each figure is built.

Only two identities reach BigQuery from GitHub Actions (ADR 0002): `ci-dbt` for pull requests,
which sees `raw` and `ci`, and `pipeline` for jobs in the `production` environment, which sees
`raw` and `prod`. A GitHub job can declare a single environment, and GitHub Pages deploys from
its own, `github-pages`.

## Decision

- **A `Docs` workflow runs after each successful Pipeline run on `main`**, and on demand. The
  published site then describes the models prod was just built from.
- **It checks out the commit the Pipeline built**, not the latest commit on `main`, so the docs
  and prod never describe different code.
- **Two jobs.** The first runs in `production` as the pipeline service account and generates
  the docs against `prod`; the second runs in `github-pages` and publishes them. Neither the
  service accounts nor their grants change.
- **One static page.** `dbt docs generate --static` embeds the manifest and the catalog in a
  single HTML file, so the site is that file and nothing else.

## Consequences

- The `pipeline` service account now serves two workflows. It is still reachable only from
  jobs in `production`, which only `main` can deploy to.
- Pages must be set to deploy from GitHub Actions (Settings, Pages, Source) before the first run.
- A change merged to `main` reaches the site only after the next Pipeline run, weekly or on
  demand, the same delay it has to reach prod.
- Generating the docs without a warehouse connection (`--empty-catalog`) would need no identity
  at all, but the site would lose column types and table sizes.
