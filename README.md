# GitHub <-> Google Cloud Workload Identity Federation Setup

Automated setup for secure, keyless authentication between GitHub Actions and Google Cloud Platform using Workload Identity Federation.

## ✨ What This Does

- 🔐 **Keyless Authentication**: No secrets to manage - uses OIDC tokens
- 🏗️ **Dedicated Project**: Creates `github-ci-blanxlait` for CI/CD isolation  
- 🎯 **Multi-Repository Support**: Works with all repos in your organization
- ⚡ **Ready to Use**: Provides exact configuration for GitHub workflows

## 🚀 Quick Start

### 1. Prerequisites Check
```bash
# Verify you have these:
gcloud auth login              # ✅ Authenticated to GCP
gcloud billing accounts list   # ✅ Have billing access
gh auth status                 # ✅ Authenticated to GitHub
```

### 2. Configure Repositories
Edit `setup.sh` to specify which repositories should have access:

```bash
# For multiple repositories (recommended):
GITHUB_REPOS=(
  "github-gcloud-wif-setup"
  "my-app-repo"
  "my-other-repo"
  # Add more repositories here
)

# For single repository:
GITHUB_REPO="specific-repo-name"  # Change from "*" to specific repo
```

### 3. Run Setup
```bash
./setup.sh
```

### 4. Use in GitHub Actions
Copy the output from the script into your workflow:

```yaml
name: Deploy to GCP
on: [push]

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
        workload_identity_provider: 'projects/146869023108/locations/global/workloadIdentityPools/github-pool/providers/github-oidc-v2'
        service_account: 'github-ci@github-ci-blanxlait.iam.gserviceaccount.com'
    
    - uses: google-github-actions/setup-gcloud@v2
    
    - name: Test GCP Access
      run: gcloud auth list
```

## 🔧 Configuration Options

### Repository Access Patterns

**Multiple Repositories (Recommended)**
```bash
# In setup.sh:
GITHUB_REPO="*"  # Keep as wildcard
GITHUB_REPOS=(
  "repo1"
  "repo2" 
  "repo3"
)
```

**Single Repository**
```bash
# In setup.sh:
GITHUB_REPO="my-specific-repo"  # Change from "*"
```

### IAM Roles Granted
- **Workload Identity User**: Allows GitHub Actions to impersonate the service account
- **Service Account Token Creator**: Allows generating access tokens (required)
- **Storage Admin**: Demo role - customize based on your needs

### Key Configuration Variables
```bash
PROJECT_ID="github-ci-blanxlait"      # Dedicated CI/CD project
GITHUB_ORG="BLANXLAIT"                # Your GitHub organization  
SERVICE_ACCOUNT_NAME="github-ci"      # Service account name
```

## 🛠️ Advanced Usage

### Adding New Repositories
1. Edit `setup.sh` and add to `GITHUB_REPOS` array:
   ```bash
   GITHUB_REPOS=(
     "existing-repo"
     "new-repo"  # Add this line
   )
   ```
2. Re-run: `./setup.sh`
3. New repo automatically gets access

### Customizing IAM Roles
Edit the script to change the default Storage Admin role:
```bash
# Replace this section with your needed roles:
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/YOUR_ROLE_HERE"
```

### Testing Your Setup
A test workflow is included in `.github/workflows/test-gcp-auth.yml` that:
- ✅ Verifies authentication works
- ✅ Tests service account permissions  
- ✅ Creates/deletes a storage bucket
- ✅ Validates the complete setup

## 📋 Troubleshooting

| Issue | Solution |
|-------|----------|
| `Permission denied` errors | Run `gcloud auth login` and ensure billing access |
| `getAccessToken permission denied` | Check that Service Account Token Creator role is granted |
| Workflow authentication fails | Verify repository is in `GITHUB_REPOS` array |
| Billing account issues | Ensure you have Billing Account User or Admin role |

## 🔍 Verification

After setup, verify everything works:
```bash
# Check created resources:
gcloud projects list --filter="name:github-ci-blanxlait"
gcloud iam service-accounts list --project=github-ci-blanxlait
gcloud iam workload-identity-pools list --location=global --project=github-ci-blanxlait

# Test the GitHub workflow:
gh workflow run "Test GCP Workload Identity Federation"
gh run list --workflow="test-gcp-auth.yml" --limit=1
```

## 📚 References

- 🔗 [Example Repository](https://github.com/BLANXLAIT/github-gcloud-wif-setup) - This repo as reference
- 📖 [Wildcard Investigation](./WILDCARD_INVESTIGATION.md) - Details on repository access patterns
- 🔧 [Setup Complete](./SETUP_COMPLETE.md) - Final configuration details
- 🛠️ [Copilot Instructions](./.github/copilot-instructions.md) - Development workflow guide

## 🏆 What You Get

✅ **Secure**: No service account keys to manage  
✅ **Scalable**: Easy to add new repositories  
✅ **Isolated**: Dedicated project for CI/CD  
✅ **Tested**: Includes validation workflow  
✅ **Documented**: Complete setup and usage guide
