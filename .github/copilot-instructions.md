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

# GitHub Copilot Instructions

## Repository Overview

This repository contains an automated setup script for GitHub Actions <-> Google Cloud Workload Identity Federation (WIF). The script creates a secure, keyless authentication mechanism between GitHub Actions and GCP without storing service account keys.

**Key Innovation**: Multi-repository support using specific IAM bindings per repository, discovered through extensive wildcard investigation.

## LLM/AI Assistant Guidelines

### When Helping Users with This Repository

#### Initial Assessment Pattern:
1. **Understand the User's Goal**:
   - Are they setting up WIF for the first time?
   - Adding a new repository to existing setup?
   - Troubleshooting authentication issues?
   - Modifying the script for custom requirements?

2. **Gather Context First**:
   - Check if `setup.sh` has been run before
   - Verify GCP project status: `gcloud config get-value project`
   - Check GitHub CLI authentication: `gh auth status`
   - Review existing GITHUB_REPOS array in setup.sh

3. **Determine User's Technical Level**:
   - New to GCP/GitHub Actions: Provide step-by-step guidance
   - Experienced: Focus on specific technical details
   - DevOps/Platform: Discuss architecture and security implications

#### Common User Scenarios and Responses:

##### Scenario 1: "I want to set up GitHub Actions to deploy to GCP"
**Response Pattern**:
```
I'll help you set up secure keyless authentication between GitHub Actions and Google Cloud using Workload Identity Federation. This eliminates the need for service account keys.

First, let me check your current setup:
1. Run: `gcloud auth list` to verify GCP authentication
2. Run: `gh auth status` to verify GitHub CLI access
3. Confirm you have billing enabled on your GCP project

Then I'll guide you through running the setup script...
```

##### Scenario 2: "I need to add another repository"
**Response Pattern**:
```
Adding a new repository is straightforward. The script supports multiple repositories through specific IAM bindings.

I'll help you:
1. Add the repository name to the GITHUB_REPOS array in setup.sh
2. Run the script to update IAM bindings
3. Test the new repository access

Let me check your current configuration first...
```

##### Scenario 3: "My workflow is failing with permission errors"
**Response Pattern**:
```
Permission errors typically indicate missing IAM roles or incorrect repository configuration. Let me help you troubleshoot:

1. First, let's check the specific error message
2. Verify your repository is in the GITHUB_REPOS array
3. Check service account IAM bindings
4. Validate Workload Identity Pool configuration

Most common fix: ensuring roles/iam.serviceAccountTokenCreator is granted...
```

#### Technical Guidance Principles:

##### Always Use Tools, Don't Assume:
- ❌ "You probably need to run setup.sh" 
- ✅ Read setup.sh to check current configuration, then guide accordingly

##### Provide Concrete Commands:
- ❌ "Check your GCP settings"
- ✅ "Run `gcloud iam service-accounts get-iam-policy github-ci@github-ci-blanxlait.iam.gserviceaccount.com --project=github-ci-blanxlait`"

##### Explain the Why:
- Don't just fix issues, explain the underlying concepts
- Reference the wildcard investigation findings when relevant
- Explain security benefits of keyless authentication

#### Repository Management Assistance:

##### For Multi-Repository Setup:
```bash
# Guide users through this pattern:
1. Edit GITHUB_REPOS array in setup.sh
2. Run: ./setup.sh
3. Test: gh workflow run "Test GCP Workload Identity Federation" --repo BLANXLAIT/new-repo
4. Verify: Check workflow logs for successful authentication
```

##### For Single Repository:
```bash
# Alternative approach for one-off additions:
1. Temporarily set GITHUB_REPO="specific-repo-name"
2. Run: ./setup.sh  
3. Revert to GITHUB_REPO="*" for future multi-repo support
```

#### Troubleshooting Assistant Approach:

##### Step 1: Identify Error Type
- **Authentication errors**: OIDC token issues, provider configuration
- **Authorization errors**: Missing IAM roles, incorrect bindings
- **Resource errors**: Missing GCP resources, project configuration
- **Script errors**: Missing dependencies, shell compatibility

##### Step 2: Systematic Diagnosis
1. **Read the error message** carefully - often contains specific resource names
2. **Check script completion** - verify setup.sh ran without errors
3. **Validate IAM bindings** - ensure repository-specific principal sets exist
4. **Test manually** - use gcloud commands to isolate the issue

##### Step 3: Solution Implementation
1. **Fix root cause** - don't just provide workarounds
2. **Test the fix** - guide user through validation
3. **Prevent recurrence** - explain how to avoid the issue

#### Code Analysis Guidelines:

##### When Reading setup.sh:
- Focus on GITHUB_REPOS array configuration
- Check if multi-repository mode is enabled (GITHUB_REPO="*")
- Verify all required GCP APIs are enabled
- Confirm IAM role assignments are comprehensive

##### When Reading Workflows:
- Verify workload_identity_provider URL format
- Check service_account email format
- Ensure OIDC authentication steps are correct
- Validate permission testing logic

#### User Education Opportunities:

##### Explain Key Concepts:
- **Workload Identity Federation**: How it eliminates keys
- **OIDC**: How GitHub provides identity tokens
- **Principal Sets**: How GCP maps GitHub identities
- **Attribute Conditions**: How organization-level security works

##### Reference Documentation:
- Point to WILDCARD_INVESTIGATION.md for technical deep-dive
- Reference README.md for user-friendly instructions
- Use SETUP_COMPLETE.md for configuration examples

#### Response Quality Standards:

##### Do:
- Always gather context before providing solutions
- Use specific file paths and line numbers when referencing code
- Provide complete command examples with expected outputs
- Explain security implications of changes
- Test suggested solutions when possible

##### Don't:
- Make assumptions about user's setup without verification
- Provide generic GCP/GitHub Actions advice without repository-specific context
- Skip validation steps in solutions
- Recommend storing service account keys (defeats the purpose)
- Ignore the multi-repository architecture when helping

#### Advanced User Support:

##### For Users Modifying the Script:
- Help them understand the step-by-step architecture
- Guide them through IAM role requirements
- Assist with custom service account configurations
- Support integration with existing GCP projects

##### For Platform Teams:
- Discuss organization-wide deployment patterns
- Help with custom OIDC attribute conditions
- Guide through enterprise security requirements
- Support integration with CI/CD pipelines

#### Emergency Support:

##### If User Has Completely Broken Setup:
1. **Don't panic** - the script is idempotent
2. **Gather state** - check what resources exist
3. **Clean slate option** - guide through resource deletion if needed
4. **Rebuild systematically** - follow the script step-by-step
5. **Document lessons** - help prevent similar issues

##### If GCP/GitHub APIs Are Down:
1. **Verify service status** - check GCP/GitHub status pages
2. **Provide workarounds** - manual authentication if possible
3. **Queue operations** - what to do when services restore
4. **Monitor and update** - keep user informed of status

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
- **GITHUB_REPOS array**: Critical for multi-repository support

#### Multi-Repository Architecture:
```bash
# In setup.sh:
GITHUB_REPO="*"  # Enables multi-repo mode
GITHUB_REPOS=(
  "repo1"
  "repo2"  
  # Add more repos here
)
```

**CRITICAL DISCOVERY**: Wildcard patterns in IAM attribute values are NOT supported:
- ❌ `principalSet://...github-pool/attribute.repository/ORG/*` (INVALID)
- ❌ `principalSet://...github-pool/*` (Valid but unreliable in practice)
- ✅ `principalSet://...github-pool/attribute.repository/ORG/specific-repo` (WORKS)

#### When Modifying setup.sh:
- Always test changes by running `./setup.sh` locally first
- The script is idempotent - safe to run multiple times
- Check that all required IAM roles are properly assigned
- Verify step numbering remains sequential after changes
- Test multi-repository configuration with multiple entries in GITHUB_REPOS

#### Repository Access Patterns Discovered:
1. **Attribute-level wildcards**: Not supported by Google Cloud IAM
2. **Pool-level wildcards**: Theoretically supported but practically unreliable
3. **Specific repository bindings**: Reliable, secure, and our chosen approach
4. **OIDC attribute conditions**: Provide organization-level security (`assertion.repository.startsWith('BLANXLAIT/')`)

#### Common Issues to Watch For:
- **Permission errors**: Usually indicate missing IAM roles
- **Resource conflicts**: Check if resources already exist with different configs
- **Project context**: Ensure `gcloud config set project` is called when needed
- **Shell compatibility**: Use `while read` instead of `mapfile` for broader support
- **Repository access**: Verify new repos are added to GITHUB_REPOS array

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
- **CRITICAL**: Grant `roles/iam.serviceAccountTokenCreator` to each repository's principalSet
- Ensure the role is granted both at project level AND on the service account itself
- For multi-repo: Verify each repository in GITHUB_REPOS has its own IAM binding
- Check Workload Identity Pool attribute conditions

#### "Attribute condition must reference provider's claims"
- Verify OIDC provider attribute mapping is correct
- Check that attribute conditions use valid assertion fields
- Ensure GitHub organization name matches exactly

#### "Repository not authenticated despite being in array"
- Verify repository name exactly matches GitHub repository name
- Check that GITHUB_REPO="*" to enable multi-repository mode
- Ensure script completed successfully and created IAM binding for that specific repository
- Validate OIDC attribute condition allows the repository

### Required IAM Roles

#### For the executing user:
- `roles/owner` (or equivalent combination)
- `roles/iam.workloadIdentityPoolAdmin`
- `roles/resourcemanager.projectIamAdmin`

#### For the service account:
- `roles/iam.workloadIdentityUser` (for each repository's GitHub Actions impersonation)
- `roles/iam.serviceAccountTokenCreator` (for each repository's access token generation)
- `roles/storage.admin` (demo role - adjust based on needs)

#### Critical IAM Pattern:
Each repository gets its own specific IAM binding:
```bash
# For BLANXLAIT/repo1:
principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/BLANXLAIT/repo1

# For BLANXLAIT/repo2: 
principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/BLANXLAIT/repo2
```

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

### Repository Management

#### Adding New Repositories (Standard Workflow):
1. **Clone this repository**:
   ```bash
   git clone https://github.com/BLANXLAIT/github-gcloud-wif-setup.git
   cd github-gcloud-wif-setup
   ```

2. **Edit GITHUB_REPOS array** in `setup.sh`:
   ```bash
   GITHUB_REPOS=(
     "existing-repo-1"
     "existing-repo-2" 
     "new-repository-name"  # Add this line
   )
   ```

3. **Run the setup script**:
   ```bash
   ./setup.sh
   ```

4. **Verify access** in the new repository by adding a test workflow or using existing workflow

#### Alternative: Direct Repository Setup
For quick one-off additions without cloning this repo:

1. **Set single repository mode**:
   ```bash
   # In setup.sh, change:
   GITHUB_REPO="new-repository-name"  # Instead of "*"
   ```

2. **Run setup script** 

3. **Revert to multi-repo mode** for future use

#### Repository Naming Requirements:
- Repository names must exactly match GitHub repository names
- Case-sensitive matching
- No wildcards or patterns supported
- Organization prefix not needed (script adds automatically)

#### Verification Commands:
```bash
# Check current repository access:
gcloud iam service-accounts get-iam-policy github-ci@github-ci-blanxlait.iam.gserviceaccount.com --project=github-ci-blanxlait

# Test access from new repository:
gh workflow run "Test GCP Workload Identity Federation" --repo BLANXLAIT/new-repo-name
```

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
