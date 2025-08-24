# GitHub <-> Google Cloud Workload Identity Federation Setup

## Overview
This repository contains a script to set up secure, keyless authentication between GitHub Actions and Google Cloud Platform using Workload Identity Federation.

## What This Does
- Creates a dedicated GCP project for CI/CD operations (`github-ci-blanxlait`)
- Sets up Workload Identity Federation with GitHub OIDC
- Creates a service account for GitHub Actions
- Configures necessary IAM permissions
- Provides the configuration for your GitHub workflows

## Prerequisites Checklist

### ✅ Google Cloud Setup
- [ ] Google Cloud CLI installed (`gcloud` command available)
- [ ] Authenticated with your GCP account (`gcloud auth login`)
- [ ] Have billing account access
- [ ] Have organization admin rights (if using GCP organization)

### ✅ GitHub Setup
- [ ] Admin access to the GitHub organization: `BLANXLAIT`
- [ ] Know which repositories need access (currently set to `*` for all repos)

### ✅ Configuration Review
Before running, review these variables in `setup.sh`:

```bash
PROJECT_ID="github-ci-blanxlait"           # New project for CI/CD
PROJECT_NAME="GitHub CI for BLANXLAIT"    # Display name
POOL_ID="github-pool"                      # Workload Identity Pool name
PROVIDER_ID="github-oidc"                  # OIDC provider name
SERVICE_ACCOUNT_NAME="github-ci"           # Service account for GitHub Actions
GITHUB_ORG="BLANXLAIT"                     # Your GitHub organization
GITHUB_REPO="*"                           # Repositories with access (* = all)
```

## Important Notes

### 🔒 Security
- **No secrets are created or stored** - uses modern keyless authentication
- **Separate project** - CI/CD operations are isolated from your main resources
- **Minimal permissions** - Only grants necessary access (currently Storage Admin for demo)

### 💰 Billing
- The script will create a new project and link it to your billing account
- CI/CD costs will be tracked separately from your main project

### 🎯 Scope
- Currently configured for all repositories in `BLANXLAIT` org
- You can restrict to specific repos by changing `GITHUB_REPO="*"` to `GITHUB_REPO="specific-repo"`

## Usage

1. **Review configuration** in `setup.sh`
2. **Run the script**: `./setup.sh`
3. **Copy the output** to your GitHub Actions workflow
4. **Adjust IAM roles** as needed for your specific use case

## Sample GitHub Actions Usage

After running the script, you'll get output like this to use in your workflows:

```yaml
- id: 'auth'
  uses: 'google-github-actions/auth@v2'
  with:
    token_format: 'access_token'
    workload_identity_provider: 'projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-oidc'
    service_account: 'github-ci@github-ci-blanxlait.iam.gserviceaccount.com'
```

## Troubleshooting

- **Authentication issues**: Run `gcloud auth login` first
- **Billing issues**: Ensure you have access to a billing account
- **Organization issues**: You may need to be an organization admin
- **API issues**: The script automatically enables required APIs

## Next Steps After Setup

1. Adjust IAM roles for the service account based on your needs
2. Test the authentication in a simple GitHub Actions workflow
3. Review the created resources in the GCP console
