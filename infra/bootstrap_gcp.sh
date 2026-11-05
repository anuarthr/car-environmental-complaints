#!/usr/bin/env bash
# Create the Google Cloud resources the pipeline needs and connect them to GitHub Actions.
#
# Safe to run more than once: every step checks for its resource before creating it, and the
# IAM grants are idempotent. Run it as the project owner after `gcloud auth login`, from Linux,
# macOS, WSL or Cloud Shell. On Windows Git Bash the .cmd wrappers break arguments that contain
# spaces, so call the SDK's own Python instead:
#   SDK="$LOCALAPPDATA/Google/Cloud SDK/google-cloud-sdk"
#   gcloud() { "$SDK/platform/bundledpython/python.exe" -S "$SDK/lib/gcloud.py" "$@"; }
#   bq() { "$SDK/platform/bundledpython/python.exe" -S "$SDK/bin/bootstrapping/bq.py" "$@"; }
#   export SDK CLOUDSDK_ROOT_DIR="$(cygpath -w "$SDK")" PATH="$(cygpath -u "$SDK")/bin:$PATH"
#   export -f gcloud bq
#
# Required:
#   BILLING_ACCOUNT  billing account id (gcloud billing accounts list)
# Optional:
#   PROJECT_ID, BUDGET_AMOUNT (in the currency of the billing account), LOCATION, GITHUB_REPO

set -euo pipefail
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

PROJECT_ID="${PROJECT_ID:-car-complaints-elt}"
PROJECT_NAME="${PROJECT_NAME:-CAR Environmental Complaints}"
BILLING_ACCOUNT="${BILLING_ACCOUNT:?Set BILLING_ACCOUNT (gcloud billing accounts list)}"
BUDGET_AMOUNT="${BUDGET_AMOUNT:-5000COP}"
LOCATION="${LOCATION:-US}"
GITHUB_REPO="${GITHUB_REPO:-anuarthr/car-environmental-complaints}"

POOL="github"
PROVIDER="car-environmental-complaints"
CI_SA="ci-dbt@${PROJECT_ID}.iam.gserviceaccount.com"
PIPELINE_SA="pipeline@${PROJECT_ID}.iam.gserviceaccount.com"

step() { printf '\n== %s\n' "$*"; }

# Strip the carriage returns that Windows builds of gcloud add to captured output.
value() { "$@" | tr -d '\r'; }

# Run one GoogleSQL statement. bq prints its errors on stdout, so show them only on failure.
sql() {
  local output
  if ! output="$(bq --headless --quiet --project_id="$PROJECT_ID" query --use_legacy_sql=false "$1" 2>&1)"; then
    echo "$output" >&2
    return 1
  fi
}

# New projects and service accounts take a few seconds to become visible to every API.
retry() {
  local attempt
  for attempt in 1 2 3 4 5 6; do
    "$@" && return 0
    echo "  not ready yet, retrying (${attempt}/6)" >&2
    sleep $((attempt * 5))
  done
  return 1
}

step "Project ${PROJECT_ID}"
if gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
  echo "already exists"
else
  gcloud projects create "$PROJECT_ID" --name="$PROJECT_NAME"
fi
PROJECT_NUMBER="$(value gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"

step "Billing"
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT" \
  --format='value(billingEnabled)'

step "APIs"
retry gcloud services enable --project="$PROJECT_ID" \
  bigquery.googleapis.com \
  billingbudgets.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com

step "Budget alert: ${BUDGET_AMOUNT} a month, for this project only"
budgets="$(value retry gcloud billing budgets list --billing-account="$BILLING_ACCOUNT" \
  --billing-project="$PROJECT_ID" --format='value(displayName)')"
if grep -qx "$PROJECT_ID" <<<"$budgets"; then
  echo "already exists"
else
  gcloud billing budgets create --billing-account="$BILLING_ACCOUNT" \
    --billing-project="$PROJECT_ID" --display-name="$PROJECT_ID" \
    --budget-amount="$BUDGET_AMOUNT" --calendar-period=month \
    --filter-projects="projects/${PROJECT_ID}" \
    --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0 \
    --threshold-rule=percent=1.0,basis=forecasted-spend --format=none
fi

step "BigQuery datasets in ${LOCATION}"
sql "CREATE SCHEMA IF NOT EXISTS \`${PROJECT_ID}.raw\` OPTIONS (location = '${LOCATION}', description = 'Append-only raw releases loaded by dlt.')"
sql "CREATE SCHEMA IF NOT EXISTS \`${PROJECT_ID}.dev\` OPTIONS (location = '${LOCATION}', description = 'dbt development target.')"
sql "CREATE SCHEMA IF NOT EXISTS \`${PROJECT_ID}.ci\` OPTIONS (location = '${LOCATION}', description = 'dbt builds from pull requests. Tables expire after one day.', default_table_expiration_days = 1)"
sql "CREATE SCHEMA IF NOT EXISTS \`${PROJECT_ID}.prod\` OPTIONS (location = '${LOCATION}', description = 'dbt production target, read by the dashboard.')"
echo "raw, dev, ci, prod"

step "Service accounts"
create_service_account() {
  local email="$1" display_name="$2"
  if gcloud iam service-accounts describe "$email" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "${email%%@*} already exists"
  else
    gcloud iam service-accounts create "${email%%@*}" --project="$PROJECT_ID" \
      --display-name="$display_name"
  fi
}
create_service_account "$CI_SA" "dbt builds from pull requests"
create_service_account "$PIPELINE_SA" "Scheduled pipeline on main"

step "Roles: both run jobs; each reads and writes only the datasets it needs"
for service_account in "$CI_SA" "$PIPELINE_SA"; do
  retry gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${service_account}" --role=roles/bigquery.jobUser \
    --condition=None --format=none
done
retry sql "GRANT \`roles/bigquery.dataViewer\` ON SCHEMA \`${PROJECT_ID}.raw\` TO 'serviceAccount:${CI_SA}'"
retry sql "GRANT \`roles/bigquery.dataEditor\` ON SCHEMA \`${PROJECT_ID}.ci\` TO 'serviceAccount:${CI_SA}'"
retry sql "GRANT \`roles/bigquery.dataEditor\` ON SCHEMA \`${PROJECT_ID}.raw\` TO 'serviceAccount:${PIPELINE_SA}'"
retry sql "GRANT \`roles/bigquery.dataEditor\` ON SCHEMA \`${PROJECT_ID}.prod\` TO 'serviceAccount:${PIPELINE_SA}'"
echo "ci-dbt: reads raw, writes ci | pipeline: writes raw and prod"

step "Workload Identity Federation for ${GITHUB_REPO}"
# Trust the numeric ids, which never change, rather than names, which can be taken over.
REPO_ID="$(value gh api "repos/${GITHUB_REPO}" --jq .id)"
OWNER_ID="$(value gh api "repos/${GITHUB_REPO}" --jq .owner.id)"
if ! gcloud iam workload-identity-pools describe "$POOL" --project="$PROJECT_ID" \
  --location=global >/dev/null 2>&1; then
  gcloud iam workload-identity-pools create "$POOL" --project="$PROJECT_ID" --location=global \
    --display-name="GitHub Actions"
fi
if ! gcloud iam workload-identity-pools providers describe "$PROVIDER" --project="$PROJECT_ID" \
  --location=global --workload-identity-pool="$POOL" >/dev/null 2>&1; then
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" --project="$PROJECT_ID" \
    --location=global --workload-identity-pool="$POOL" \
    --display-name="car-environmental-complaints" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository_id=assertion.repository_id,attribute.repository_owner_id=assertion.repository_owner_id" \
    --attribute-condition="assertion.repository_id == '${REPO_ID}' && assertion.repository_owner_id == '${OWNER_ID}'"
fi
POOL_NAME="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL}"
retry gcloud iam service-accounts add-iam-policy-binding "$CI_SA" --project="$PROJECT_ID" \
  --role=roles/iam.workloadIdentityUser --format=none \
  --member="principal://iam.googleapis.com/${POOL_NAME}/subject/repo:${GITHUB_REPO}:pull_request"
retry gcloud iam service-accounts add-iam-policy-binding "$PIPELINE_SA" --project="$PROJECT_ID" \
  --role=roles/iam.workloadIdentityUser --format=none \
  --member="principal://iam.googleapis.com/${POOL_NAME}/subject/repo:${GITHUB_REPO}:environment:production"
echo "pull requests -> ci-dbt | environment production -> pipeline"

step "GitHub environment 'production', deployable only from main"
gh api --method PUT "repos/${GITHUB_REPO}/environments/production" \
  -F "deployment_branch_policy[protected_branches]=false" \
  -F "deployment_branch_policy[custom_branch_policies]=true" --silent
policies="$(value gh api "repos/${GITHUB_REPO}/environments/production/deployment-branch-policies" \
  --jq '.branch_policies[].name')"
if ! grep -qx main <<<"$policies"; then
  gh api --method POST "repos/${GITHUB_REPO}/environments/production/deployment-branch-policies" \
    -f name=main -f type=branch --silent
fi
echo "production <- main"

step "Repository variables read by the workflows"
gh variable set GCP_PROJECT_ID --repo "$GITHUB_REPO" --body "$PROJECT_ID"
gh variable set GCP_WIF_PROVIDER --repo "$GITHUB_REPO" --body "${POOL_NAME}/providers/${PROVIDER}"
gh variable set GCP_CI_SERVICE_ACCOUNT --repo "$GITHUB_REPO" --body "$CI_SA"
gh variable set GCP_PIPELINE_SERVICE_ACCOUNT --repo "$GITHUB_REPO" --body "$PIPELINE_SA"

step "Done"
echo "Project:  ${PROJECT_ID} (${PROJECT_NUMBER})"
echo "Provider: ${POOL_NAME}/providers/${PROVIDER}"
