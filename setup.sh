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
PROVIDER_ID="github-oidc-v2"
SERVICE_ACCOUNT_NAME="github-ci"
GITHUB_ORG="BLANXLAIT"

# Repository Configuration:
# For multiple repositories: Keep GITHUB_REPO="*" and list repos in GITHUB_REPOS array
# For single repository: Set GITHUB_REPO to specific repo name (e.g., "my-repo")
GITHUB_REPO="*"  # Set to "*" for all repos, or specific repo name for single repo

# List of specific repositories to grant access to (used when GITHUB_REPO="*")
# Add new repositories here as needed
GITHUB_REPOS=(
  "github-gcloud-wif-setup"
  "blanxlait-infrastructure"
)
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
if [[ "$GITHUB_REPO" == "*" ]]; then
echo "  8. Configure access for ${#GITHUB_REPOS[@]} repositories in $GITHUB_ORG organization"
else
echo "  8. Configure access for $GITHUB_ORG/$GITHUB_REPO repository"
fi
echo "  9. Print the config you need for GitHub Actions"
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
    --attribute-condition="assertion.repository.startsWith('$GITHUB_ORG/')"
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
if [[ "$GITHUB_REPO" == "*" ]]; then
  echo "  Configuring access for multiple repositories in $GITHUB_ORG organization..."
  for repo in "${GITHUB_REPOS[@]}"; do
    MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_ORG/$repo"
    echo "  Granting access to: $GITHUB_ORG/$repo"
    
    if ! gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT_EMAIL" \
          --project="$PROJECT_ID" \
          --format="json" | grep -q "$MEMBER"; then
      gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
        --project="$PROJECT_ID" \
        --role="roles/iam.workloadIdentityUser" \
        --member="$MEMBER"
    else
      echo "    Access already granted for $repo"
    fi
  done
else
  # Single repository configuration
  MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_ORG/$GITHUB_REPO"
  if ! gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT_EMAIL" \
        --project="$PROJECT_ID" \
        --format="json" | grep -q "$MEMBER"; then
    
    # Remove old bindings if they exist (cleanup from provider changes)
    echo "  Cleaning up old Workload Identity User bindings..."
    OLD_MEMBERS=$(gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT_EMAIL" \
      --project="$PROJECT_ID" \
      --format="json" | jq -r '.bindings[] | select(.role=="roles/iam.workloadIdentityUser") | .members[]' | grep principalSet || true)
    
    for OLD_MEMBER in $OLD_MEMBERS; do
      if [[ "$OLD_MEMBER" != "$MEMBER" ]]; then
        echo "  Removing old binding: $OLD_MEMBER"
        gcloud iam service-accounts remove-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
          --project="$PROJECT_ID" \
          --role="roles/iam.workloadIdentityUser" \
          --member="$OLD_MEMBER" 2>/dev/null || true
      fi
    done
    
    # Add the correct binding
    gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
      --project="$PROJECT_ID" \
      --role="roles/iam.workloadIdentityUser" \
      --member="$MEMBER"
  else
    echo "  Workload Identity User role already granted."
  fi
fi

echo "Step 11: Granting Service Account Token Creator role to external identity..."
# This is the CRITICAL role that allows GitHub Actions to generate access tokens
# for the service account. Without this, you get "getAccessToken permission denied"
if [[ "$GITHUB_REPO" == "*" ]]; then
  echo "  Configuring token creator access for multiple repositories..."
  for repo in "${GITHUB_REPOS[@]}"; do
    MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_ORG/$repo"
    echo "  Granting token creator access to: $GITHUB_ORG/$repo"
    
    if ! gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT_EMAIL" \
          --project="$PROJECT_ID" \
          --format="json" | grep -q "$MEMBER.*roles/iam.serviceAccountTokenCreator"; then
      gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
        --project="$PROJECT_ID" \
        --member="$MEMBER" \
        --role="roles/iam.serviceAccountTokenCreator"
    else
      echo "    Token creator access already granted for $repo"
    fi
  done
else
  # Single repository configuration
  MEMBER="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_ORG/$GITHUB_REPO"
  if ! gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT_EMAIL" \
        --project="$PROJECT_ID" \
        --format="json" | grep -q "$MEMBER.*roles/iam.serviceAccountTokenCreator"; then
    gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT_EMAIL" \
      --project="$PROJECT_ID" \
      --member="$MEMBER" \
      --role="roles/iam.serviceAccountTokenCreator"
  else
    echo "  Service Account Token Creator role (external identity) already granted."
  fi
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

echo "Step 13: Validating setup..."
echo "  Verifying Workload Identity Pool exists..."
if gcloud iam workload-identity-pools describe "$POOL_ID" --project="$PROJECT_ID" --location="global" &>/dev/null; then
  echo "  ✅ Workload Identity Pool verified"
else
  echo "  ❌ Workload Identity Pool validation failed"
  exit 1
fi

echo "  Verifying OIDC provider exists..."
if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
    --location="global" \
    --workload-identity-pool="$POOL_ID" \
    --project="$PROJECT_ID" &>/dev/null; then
  echo "  ✅ OIDC provider verified"
else
  echo "  ❌ OIDC provider validation failed"
  exit 1
fi

echo "  Verifying service account exists..."
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
  echo "  ✅ Service account verified"
else
  echo "  ❌ Service account validation failed"
  exit 1
fi

echo "  Verifying IAM bindings..."
SA_POLICY=$(gcloud iam service-accounts get-iam-policy "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" --format="json")
if echo "$SA_POLICY" | grep -q "workloadIdentityUser" && echo "$SA_POLICY" | grep -q "serviceAccountTokenCreator"; then
  echo "  ✅ IAM bindings verified"
else
  echo "  ❌ IAM bindings validation failed"
  echo "  Missing required roles on service account"
  exit 1
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
echo "  - IAM Roles:                 Workload Identity User, Service Account Token Creator (external identity), Storage Admin"
if [[ "$GITHUB_REPO" == "*" ]]; then
  echo "  - Repository Access:         ${#GITHUB_REPOS[@]} repositories in $GITHUB_ORG organization"
  for repo in "${GITHUB_REPOS[@]}"; do
    echo "    • $GITHUB_ORG/$repo"
  done
else
  echo "  - Repository Access:         $GITHUB_ORG/$GITHUB_REPO"
fi
echo ""
echo "Next steps:"
echo "  1. Copy the workflow configuration below into your GitHub Actions"
echo "  2. Test with: gh workflow run 'Test GCP Workload Identity Federation'"
echo "  3. Adjust IAM roles for the service account based on your specific needs"
echo "  4. Add new repositories by editing GITHUB_REPOS array and re-running this script"
echo ""
echo "📋 GitHub Actions Workflow Configuration:"
echo ""
echo "workload_identity_provider: 'projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID'"
echo "service_account: '$SERVICE_ACCOUNT_EMAIL'"
echo ""
cat <<EOF
# Add to your .github/workflows/*.yml file:
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # Required for OIDC
    steps:
    - uses: actions/checkout@v4
    - id: auth
      uses: google-github-actions/auth@v2
      with:
        workload_identity_provider: 'projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID'
        service_account: '$SERVICE_ACCOUNT_EMAIL'
    - uses: google-github-actions/setup-gcloud@v2
    - name: Test GCP Access
      run: gcloud auth list
EOF
echo ""
echo "🔗 Reference Links:"
echo "  • Test this setup: gh workflow run 'Test GCP Workload Identity Federation'"
echo "  • Documentation: $(pwd)/README.md"
echo "  • Troubleshooting: $(pwd)/WILDCARD_INVESTIGATION.md"
echo "======================================================"
