# GitHub Copilot Instructions

## Repository Overview

This repository contains an automated setup script for GitHub Actions <-> Google Cloud Workload Identity Federation (WIF). The script creates a secure, keyless authentication mechanism between GitHub Actions and GCP without storing service account keys.

## Development Workflow

### Primary Workflow Pattern
When making changes to this project, follow this iterative pattern:

1. **Modify the script** (`setup.sh`) to fix issues or add features
2. **Run the script locally** to test changes and apply updates to GCP resources
3. **Test the workflow** by triggering the GitHub Actions workflow
4. **Monitor and troubleshoot** the workflow execution until it passes
5. **Commit changes** only after successful testing

### Script Development Guidelines

#### Key Components to Understand:
- **setup.sh**: Main automation script that creates GCP resources
- **test-gcp-auth.yml**: GitHub Actions workflow that validates the WIF setup
- **Configuration**: Variables at top of setup.sh control org/project settings

#### When Modifying setup.sh:
- Always test changes by running `./setup.sh` locally first
- The script is idempotent - safe to run multiple times
- Check that all required IAM roles are properly assigned
- Verify step numbering remains sequential after changes

#### Common Issues to Watch For:
- **Permission errors**: Usually indicate missing IAM roles
- **Resource conflicts**: Check if resources already exist with different configs
- **Project context**: Ensure `gcloud config set project` is called when needed
- **Shell compatibility**: Use `while read` instead of `mapfile` for broader support

### Testing Workflow

#### GitHub Actions Monitoring:
- Use `gh workflow run "Test GCP Workload Identity Federation"` to trigger tests
- Monitor with `gh run list --workflow="test-gcp-auth.yml" --limit=5`
- Get detailed logs with `gh run view <run-id> --log-failed`
- Check specific job logs for debugging

#### Expected Test Flow:
1. **Authentication**: OIDC token exchange with GCP
2. **Service Account Impersonation**: Generate access tokens
3. **Permission Testing**: Verify Storage Admin and other roles work
4. **Resource Creation**: Test bucket creation/deletion
5. **Cleanup**: Ensure test resources are removed

### Troubleshooting Common Errors

#### "Permission 'iam.serviceAccounts.getAccessToken' denied"
- Add `roles/iam.serviceAccountTokenCreator` to the service account
- Ensure the role is granted both at project level AND on the service account itself
- Check Workload Identity Pool attribute conditions

#### "PERMISSION_DENIED: Permission 'iam.workloadIdentityPools.create' denied"
- Verify user has `roles/iam.workloadIdentityPoolAdmin`
- Ensure project is set as active: `gcloud config set project <project-id>`
- Check that required APIs are enabled

#### "Attribute condition must reference provider's claims"
- Verify OIDC provider attribute mapping is correct
- Check that attribute conditions use valid assertion fields
- Ensure GitHub organization name matches exactly

### Required IAM Roles

#### For the executing user:
- `roles/owner` (or equivalent combination)
- `roles/iam.workloadIdentityPoolAdmin`
- `roles/resourcemanager.projectIamAdmin`

#### For the service account:
- `roles/iam.workloadIdentityUser` (for GitHub Actions impersonation)
- `roles/iam.serviceAccountTokenCreator` (for access token generation)
- `roles/storage.admin` (demo role - adjust based on needs)

### GCP Resources Created

#### Project Structure:
- **Project ID**: `github-ci-blanxlait`
- **Workload Identity Pool**: `github-pool`
- **OIDC Provider**: `github-oidc`
- **Service Account**: `github-ci@github-ci-blanxlait.iam.gserviceaccount.com`

#### Key Configuration:
```yaml
workload_identity_provider: 'projects/146869023108/locations/global/workloadIdentityPools/github-pool/providers/github-oidc'
service_account: 'github-ci@github-ci-blanxlait.iam.gserviceaccount.com'
```

### Git Workflow

#### Commit Guidelines:
- Only commit after successful workflow runs
- Use descriptive commit messages explaining the fix/change
- Include error messages being resolved in commit descriptions
- Test script changes before committing

#### Branch Strategy:
- Work directly on `main` for this repository
- Use `git add setup.sh` to stage only script changes when needed
- Push changes after local testing and workflow validation

### Automation Commands

#### Quick Testing Sequence:
```bash
# 1. Run script locally
echo "y" | ./setup.sh

# 2. Trigger workflow
gh workflow run "Test GCP Workload Identity Federation"

# 3. Monitor results
gh run list --workflow="test-gcp-auth.yml" --limit=1

# 4. Check logs if failed
gh run view $(gh run list --workflow="test-gcp-auth.yml" --limit=1 --json databaseId --jq '.[0].databaseId') --log-failed
```

#### Useful GCP Commands:
```bash
# Check service account roles
gcloud iam service-accounts get-iam-policy github-ci@github-ci-blanxlait.iam.gserviceaccount.com --project=github-ci-blanxlait

# Check project-level permissions
gcloud projects get-iam-policy github-ci-blanxlait --format="table(bindings.role,bindings.members.flatten())"

# Test Workload Identity Pool
gcloud iam workload-identity-pools describe github-pool --location=global --project=github-ci-blanxlait
```

### Security Considerations

#### Best Practices:
- No secrets or private keys are created or stored
- Uses modern OIDC-based keyless authentication
- Separate project isolates CI/CD from production resources
- Minimal required permissions following principle of least privilege

#### Configuration Security:
- Repository access can be restricted by changing `GITHUB_REPO="*"` to specific repos
- Service account permissions should be tailored to actual CI/CD needs
- Regularly review IAM policies and remove unused permissions

### Documentation Updates

When making significant changes:
- Update README.md with new configuration steps
- Update SETUP_COMPLETE.md with current outputs
- Modify this file to reflect new workflows or common issues
- Update workflow comments to explain any new test steps

### Emergency Procedures

#### If Workflow Consistently Fails:
1. Check GCP Console for recent policy changes
2. Verify GitHub Actions service is operational
3. Test authentication manually with gcloud CLI
4. Recreate Workload Identity Pool if corrupted
5. Contact support if GCP APIs are having issues

#### Resource Cleanup:
If you need to start fresh:
```bash
# Delete the project (WARNING: destructive)
gcloud projects delete github-ci-blanxlait

# Or selectively delete WIF resources
gcloud iam workload-identity-pools delete github-pool --location=global --project=github-ci-blanxlait
```
