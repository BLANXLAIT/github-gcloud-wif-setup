# Wildcard Support Investigation Results

## Problem Statement
We wanted to configure Workload Identity Federation to work with **all repositories** in the BLANXLAIT organization, not just a single specific repository.

## What We Discovered

### ❌ Attribute-level wildcards are NOT supported
```bash
# This does NOT work:
principalSet://iam.googleapis.com/projects/PROJECT/locations/global/workloadIdentityPools/POOL/attribute.repository/BLANXLAIT/*
```
The wildcard `*` is not supported in attribute values. The attribute value must be an exact literal match.

### 🤔 Pool-level wildcards are supported but unreliable
```bash
# This is valid but seems to have issues:
principalSet://iam.googleapis.com/projects/PROJECT/locations/global/workloadIdentityPools/POOL/*
```
According to the documentation, this should work and would allow any identity in the pool. However, in practice we experienced authentication failures even with proper OIDC attribute conditions.

### ✅ Specific repository bindings work reliably
```bash
# This works perfectly:
principalSet://iam.googleapis.com/projects/PROJECT/locations/global/workloadIdentityPools/POOL/attribute.repository/BLANXLAIT/specific-repo
```

## Our Solution

Since we need reliable access to multiple repositories, we implemented a **multiple specific bindings** approach:

1. **Configuration**: List all desired repositories in the `GITHUB_REPOS` array in `setup.sh`
2. **IAM Bindings**: Script creates individual IAM bindings for each repository
3. **Security**: Still protected by OIDC attribute condition `assertion.repository.startsWith('BLANXLAIT/')`

### Benefits:
- ✅ **Reliable**: Uses proven specific repository bindings
- ✅ **Secure**: Each repository explicitly granted access
- ✅ **Manageable**: Easy to add new repositories by editing the array
- ✅ **Auditable**: Clear IAM policy showing exactly which repos have access

### To add a new repository:
1. Edit `setup.sh`
2. Add repository name to `GITHUB_REPOS` array
3. Run `./setup.sh` again

## Current Configuration

The setup is configured for multiple repositories with these specific bindings:
- `BLANXLAIT/github-gcloud-wif-setup`

To add more repositories, edit the `GITHUB_REPOS` array in `setup.sh`:
```bash
GITHUB_REPOS=(
  "github-gcloud-wif-setup"
  "my-new-repo"
  "another-repo"
)
```

## References
- [Google Cloud Principal Identifiers](https://cloud.google.com/iam/docs/principal-identifiers)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub Actions Auth Action](https://github.com/google-github-actions/auth)
