#!/bin/bash

# =============================================================================
# GitHub <-> Google Cloud Workload Identity Federation Setup Script
# =============================================================================
#
# PURPOSE:
# This script automates the setup of Workload Identity Federation between 
# GitHub Actions and Google Cloud Platform, allowing your GitHub workflows
# to authenticate with GCP without storing service account keys.
#
# WHAT IT DOES:
# 1. Creates a new GCP project (or uses existing one)
# 2. Sets up Workload Identity Pool and OIDC provider for GitHub
# 3. Creates a service account for GitHub Actions
# 4. Configures IAM bindings for secure authentication
# 5. Outputs the configuration needed for your GitHub workflows
#
# PREREQUISITES:
# - Google Cloud CLI installed and configured
# - Authenticated with a GCP account that has billing/organization access
# - GitHub repository you want to grant access to
#
# USAGE:
# 1. Edit the USER VARIABLES section below with your details
# 2. Run: ./setup.sh
# 3. Copy the output configuration to your GitHub Actions workflow
#
# SECURITY NOTE:
# No secrets or private keys are created or stored. This uses modern
# keyless authentication via OpenID Connect (OIDC).
#
# =============================================================================

set -euo pipefail

# ==== USER VARIABLES ====
PROJECT_ID="github-ci-blanxlait"
PROJECT_NAME="GitHub CI for BLANXLAIT"
POOL_ID="github-pool"
PROVIDER_ID="github-oidc"
SERVICE_ACCOUNT_NAME="github-ci"
GITHUB_ORG="BLANXLAIT"
GITHUB_REPO="*"
# ========================

echo "======================================================"
echo "      GCP <-> GitHub Workload Identity Federation"
echo "======================================================"
echo "This script will:"
echo "  1. Ensure you are logged in to GCP"
echo "  2. Detect or prompt for your billing account and org"
echo "  3. Create (or reuse) a GCP project for CI/CD"
echo "  4. Enable IAM APIs"
echo "  5. Set up a Workload Identity Pool and GitHub OIDC provider"
echo "  6. Create (or reuse) a service account for GitHub Actions"
echo "  7. Grant permissions (Workload Identity User and Storage Admin)"
echo "  8. Print the config you need for GitHub Actions"
echo ""
echo "You will need:"
echo "  - Owner/admin access to your GCP org and billing account"
echo "  - Owner/admin access to your GitHub org ($GITHUB_ORG)"
echo "  - Optionally, your billing account and org ID if you have more than one"
echo ""
echo "No secrets, tokens, or private keys will be stored or printed."
echo ""
echo "Proceed? (y/n)"
read -r CONT
if [[ "$CONT" != "y" && "$CONT" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Step 1: Checking GCP authentication..."
if ! gcloud auth list --format="value(account)" | grep -q "@"; then
  echo "  Not logged in. Please login:"
  gcloud auth login
else
  echo "  You are logged in as: $(gcloud config get-value account)"
fi

echo "Step 2: Detecting billing account..."
if [ -z "${BILLING_ACCOUNT_ID:-}" ]; then
  # Use while read instead of mapfile for better compatibility
  OPEN_ACCOUNTS=()
  while IFS= read -r entry; do
    if [[ $entry == *"True" ]]; then
      OPEN_ACCOUNTS+=("$entry")
    fi
  done < <(gcloud beta billing accounts list --format="value(ACCOUNT_ID,NAME,OPEN)")
  if [[ ${#OPEN_ACCOUNTS[@]} -eq 0 ]]; then
    echo "No open billing accounts found. Please create one in the GCP Console."
    exit 1
  elif [[ ${#OPEN_ACCOUNTS[@]} -eq 1 ]]; then
    BILLING_ACCOUNT_ID=$(echo "${OPEN_ACCOUNTS[0]}" | awk '{print $1}')
    echo "  Using billing account: $BILLING_ACCOUNT_ID"
  else
    echo "Multiple billing accounts found. Select one:"
    select ENTRY in "${OPEN_ACCOUNTS[@]}"; do
      BILLING_ACCOUNT_ID=$(echo "$ENTRY" | awk '{print $1}')
      break
    done
  fi
fi

echo "Step 3: Detecting GCP organization..."
if [ -z "${ORG_ID:-}" ]; then
  ORGS=$(gcloud organizations list --format="value(ID,DISPLAY_NAME)")
  if [[ -z "$ORGS" ]]; then
    echo "  No GCP orgs found. Project will be created in your personal account."
    ORG_ID=""
  else
    # Use while read instead of mapfile for better compatibility
    ORG_LIST=()
    while IFS= read -r entry; do
      ORG_LIST+=("$entry")
    done <<< "$ORGS"
    if [[ ${#ORG_LIST[@]} -eq 1 ]]; then
      ORG_ID=$(echo "${ORG_LIST[0]}" | awk '{print $1}')
      echo "  Using org: $ORG_ID"
    else
      echo "Multiple organizations found. Select one:"
      select ENTRY in "${ORG_LIST[@]}"; do
        ORG_ID=$(echo "$ENTRY" | awk '{print $1}')
        break
      done
    fi
  fi
fi

echo "Step 4: Creating or using project $PROJECT_ID ..."
check_project_exists() {
  gcloud projects describe "$1" &>/dev/null
}
if check_project_exists "$PROJECT_ID"; then
  echo "  Project already exists."
else
  echo "  Creating project..."
  if [[ -n "$ORG_ID" ]]; then
    gcloud projects create "$PROJECT_ID" --name="$PROJECT_NAME" --organization="$ORG_ID"
  else
    gcloud projects create "$PROJECT_ID" --name="$PROJECT_NAME"
  fi
  echo "  Waiting for project creation..."
  until check_project_exists "$PROJECT_ID"; do
    sleep 2
  done
fi

echo "Step 5: Linking billing account..."
CURRENT_BILLING=$(gcloud beta billing projects describe "$PROJECT_ID" --format="value(billingAccountName)" 2>/dev/null || echo "")
if [[ "$CURRENT_BILLING" != "billingAccounts/$BILLING_ACCOUNT_ID" ]]; then
  echo "  Linking billing account $BILLING_ACCOUNT_ID..."
  gcloud beta billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT_ID"
else
  echo "  Billing already linked."
fi

echo "Step 6: Enabling required APIs..."
gcloud services enable iamcredentials.googleapis.com iam.googleapis.com cloudresourcemanager.googleapis.com --project="$PROJECT_ID"

echo "Step 6.5: Granting IAM Admin role to current user..."
CURRENT_USER=$(gcloud config get-value account)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:$CURRENT_USER" \
  --role="roles/resourcemanager.projectIamAdmin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:$CURRENT_USER" \
  --role="roles/iam.workloadIdentityPoolAdmin"

echo "  Setting project as active context..."
gcloud config set project "$PROJECT_ID"

echo "  Waiting for permissions to propagate..."
sleep 5

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')

echo "Step 7: Creating or reusing Workload Identity Pool..."
if ! gcloud iam workload-identity-pools describe "$POOL_ID" --project="$PROJECT_ID" --location="global" &>/dev/null; then
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --project="$PROJECT_ID" \
    --location="global" \
    --display-name="GitHub Actions Pool"
else
  echo "  Pool already exists."
fi

echo "Step 8: Creating or reusing OIDC provider..."
if ! gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
      --location="global" \
      --workload-identity-pool="$POOL_ID" \
      --project="$PROJECT_ID" &>/dev/null; then
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --project="$PROJECT_ID" \
    --location="global" \
    --workload-identity-pool="$POOL_ID" \
    --display-name="GitHub Actions OIDC" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor" \
    --attribute-condition="assertion.repository_owner=='$GITHUB_ORG'"
else
  echo "  Provider already exists."
fi

SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Step 9: Creating or reusing service account..."
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --project="$PROJECT_ID" \
    --display-name="GitHub Actions Service Account"
else
  echo "  Service account already exists."
fi

echo "Step 10: Granting Workload Identity User role..."
MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_ORG/$GITHUB_REPO"
if ! gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT_EMAIL" \
      --project="$PROJECT_ID" \
      --format="json" | grep -q "$MEMBER"; then
  gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
    --project="$PROJECT_ID" \
    --role="roles/iam.workloadIdentityUser" \
    --member="$MEMBER"
else
  echo "  Workload Identity User role already granted."
fi

echo "Step 11: Granting Service Account Token Creator role..."
if ! gcloud projects get-iam-policy "$PROJECT_ID" \
      --format="json" | grep -q "serviceAccount:$SERVICE_ACCOUNT_EMAIL.*roles/iam.serviceAccountTokenCreator"; then
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/iam.serviceAccountTokenCreator"
else
  echo "  Service Account Token Creator role already granted."
fi

echo "Step 12: Granting Storage Admin role (for demo, adjust as needed)..."
if ! gcloud projects get-iam-policy "$PROJECT_ID" \
      --format="json" | grep -q "serviceAccount:$SERVICE_ACCOUNT_EMAIL.*roles/storage.admin"; then
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
    --role="roles/storage.admin"
else
  echo "  Storage Admin role already granted."
fi

echo ""
echo "======================================================"
echo " SETUP COMPLETE"
echo "======================================================"
echo "The following resources were created or updated:"
echo "  - Project:          $PROJECT_ID ($PROJECT_NAME)"
echo "  - Billing Account:  $BILLING_ACCOUNT_ID"
if [[ -n "${ORG_ID:-}" ]]; then
  echo "  - Organization:     $ORG_ID"
fi
echo "  - Workload Identity Pool:    $POOL_ID"
echo "  - OIDC Provider:             $PROVIDER_ID"
echo "  - Service Account:           $SERVICE_ACCOUNT_EMAIL"
echo "  - IAM Roles:                 Workload Identity User, Service Account Token Creator, Storage Admin"
echo ""
echo "Next steps:"
echo "  1. Use the values below in your GitHub Actions workflow"
echo "  2. Adjust IAM roles for the service account if you need more or less access"
echo "  3. (Optional) Review the service account and WIF pool in the GCP console"
echo ""
echo "Paste these into your workflow:"
echo ""
echo "workload_identity_provider: 'projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID'"
echo "service_account: '$SERVICE_ACCOUNT_EMAIL'"
echo ""
cat <<EOF
- id: 'auth'
  uses: 'google-github-actions/auth@v2'
  with:
    token_format: 'access_token'
    workload_identity_provider: 'projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID'
    service_account: '$SERVICE_ACCOUNT_EMAIL'
EOF
echo ""
echo "Questions or problems? Review the output above or check GCP & GitHub docs."
echo "======================================================"
