# GitHub <-> Google Cloud Workload Identity Federation Setup

Automated setup for secure, keyless authentication between GitHub Actions and Google Cloud Platform using Workload Identity Federation.

## ✨ What This Does

- 🔐 **Keyless Authentication**: No secrets to manage - uses OIDC tokens
- 🏗️ **Dedicated Project**: Creates `github-ci-blanxlait` for CI/CD isolation  
- 🎯 **Multi-Repository Support**: Each repository gets individual IAM bindings for security
- ⚡ **Ready to Use**: Provides exact configuration for GitHub workflows
- 🔍 **Battle-Tested**: Includes comprehensive validation and troubleshooting

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
GITHUB_REPO="specific-repo-name"  # Script processes single repo instead of array
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
      uses: google-github-actions/auth@v2.1.12
      with:
        workload_identity_provider: 'projects/146869023108/locations/global/workloadIdentityPools/github-pool/providers/github-oidc'
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
GITHUB_REPO="*"  # Enables multi-repository mode (script internal flag)
GITHUB_REPOS=(
  "repo1"
  "repo2" 
  "repo3"
)
```
> 🔍 **Technical Note**: Each repository gets its own specific IAM binding. Google Cloud IAM requires individual principal sets per repository - there's no wildcard support for attribute values. This approach provides better security and reliability.

**Single Repository**
```bash
# In setup.sh:
GITHUB_REPO="my-specific-repo"  # Script processes single repo instead of array
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
1. **Clone this setup repository**:
   ```bash
   git clone https://github.com/BLANXLAIT/github-gcloud-wif-setup.git
   cd github-gcloud-wif-setup
   ```

2. **Edit `setup.sh`** and add to `GITHUB_REPOS` array:
   ```bash
   GITHUB_REPOS=(
     "existing-repo"
     "new-repo"  # Add this line
   )
   ```

3. **Re-run the setup**:
   ```bash
   ./setup.sh
   ```

4. **Verify access** in your new repository by adding the workflow configuration

> 💡 **Pro Tip**: The script is idempotent - safe to run multiple times. Only new repositories will get IAM bindings added.

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
| `getAccessToken permission denied` | Ensure Service Account Token Creator role is granted to your repository's principal set |
| `Repository not authenticated` | Verify repository name exactly matches GitHub repo name in `GITHUB_REPOS` array |
| `OIDC token exchange failed` | Check Workload Identity Pool configuration and GitHub OIDC provider setup |
| Workflow authentication fails | Confirm `GITHUB_REPO="*"` enables multi-repo mode and repository is listed in `GITHUB_REPOS` array |
| Billing account issues | Ensure you have Billing Account User or Admin role |

### Common Error Patterns
- **"Principal does not exist"**: Repository not in `GITHUB_REPOS` array or name mismatch
- **"Attribute condition failed"**: Repository not under the `BLANXLAIT` organization
- **"Token Creator permission denied"**: Missing `roles/iam.serviceAccountTokenCreator` binding

## 🔍 Verification

After setup, verify everything works:
```bash
# Check created resources:
gcloud projects list --filter="name:github-ci-blanxlait"
gcloud iam service-accounts list --project=github-ci-blanxlait
gcloud iam workload-identity-pools list --location=global --project=github-ci-blanxlait

# Verify repository-specific access:
gcloud iam service-accounts get-iam-policy github-ci@github-ci-blanxlait.iam.gserviceaccount.com --project=github-ci-blanxlait

# Test the GitHub workflow:
gh workflow run "Test GCP Workload Identity Federation"
gh run list --workflow="test-gcp-auth.yml" --limit=1
```

## 📚 References

- 🔗 [GitHub Repository](https://github.com/BLANXLAIT/github-gcloud-wif-setup) - This repo for reference and cloning
- 📖 [IAM Limitations Investigation](./WILDCARD_INVESTIGATION.md) - Technical analysis of Google Cloud IAM pattern limitations
- 🔧 [Setup Complete](./SETUP_COMPLETE.md) - Final configuration details and outputs
- 🛠️ [Copilot Instructions](./.github/copilot-instructions.md) - Development workflow and AI assistance guide
- 📋 [Google Cloud Documentation](https://cloud.google.com/iam/docs/workload-identity-federation) - Official WIF documentation

## 🔧 Architecture Details

This setup creates a **secure, repository-specific access pattern**:

1. **Workload Identity Pool**: Maps GitHub OIDC tokens to GCP identities
2. **Individual IAM Bindings**: Each repository gets its own principal set for security
3. **Service Account**: Dedicated `github-ci` account with minimal required permissions
4. **Organization-Level Security**: OIDC attribute conditions ensure only your org's repos can authenticate

> 🔍 **Why Individual Bindings?** Google Cloud IAM requires specific repository names in principal sets - there's no support for patterns like `attribute.repository/ORG/*`. This limitation led us to create individual bindings per repository, which actually provides superior security and auditability.

## 🏆 What You Get

✅ **Secure**: No service account keys to manage  
✅ **Scalable**: Easy to add new repositories with individual IAM bindings  
✅ **Isolated**: Dedicated project for CI/CD operations  
✅ **Tested**: Includes comprehensive validation workflow  
✅ **Documented**: Complete setup, usage, and troubleshooting guide  
✅ **Battle-Proven**: Extensively tested through IAM limitations investigation and multi-repository scenarios
