# ADR 0002: Keyless, least-privilege access to Google Cloud

- Status: accepted
- Date: 2026-11-05

## Context

The repository is public, so its workflows and their logs are public too. CI has to build dbt
models on every pull request, and a scheduled job has to load data and publish the production
models. Neither may hold a long-lived credential, and a pull request must never be able to
change production data.

## Decision

- **No service account keys.** GitHub Actions exchanges its OIDC token for short-lived Google
  credentials through Workload Identity Federation.
- **The federation trusts numeric ids, not names.** The provider only accepts tokens whose
  `repository_id` and `repository_owner_id` match this repository, so a repository that later
  takes the same name gets nothing.
- **Two service accounts, each bound to one kind of job:**

  | Service account | Who can use it | Reads | Writes |
  |---|---|---|---|
  | `ci-dbt` | Jobs triggered by pull requests (subject `repo:<repo>:pull_request`) | `raw` | `ci` |
  | `pipeline` | Jobs in the GitHub environment `production`, which only `main` can deploy to | `raw`, `prod` | `raw`, `prod` |

- **Permissions are granted per dataset** with BigQuery DCL (`GRANT ... ON SCHEMA`). At project
  level both accounts only hold `roles/bigquery.jobUser`, which lets them run jobs. The `dev`
  dataset is for local work, and neither account can reach it.
- **Tables in `ci` expire after one day**, so pull request builds clean up after themselves.
- **Every pull request checks the boundary.** The `Cloud access` CI job takes the pull request
  identity and asserts that it reaches `raw` and `ci` and is refused on `prod` and `dev`.
- **A budget alert of 5,000 COP a month** (about 1 USD), filtered to this project, warns at 50,
  90 and 100 percent of actual spend and at 100 percent of forecasted spend.
- **`infra/bootstrap_gcp.sh` creates all of it** and is safe to run again.

## Consequences

- Pull requests from forks and from Dependabot receive no OIDC token, so they skip the cloud
  check. They still run lint, tests and the secret scan.
- A new dataset or a new kind of job means editing the bootstrap script and running it again,
  never clicking through the console.
- A budget alert warns but does not stop spending. `maximum_bytes_billed` in the dbt profiles
  caps each query.
