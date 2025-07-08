# Kubeflow Deployment with ArgoCD Sync Waves

This document explains the sync wave approach used for deploying Kubeflow in our GitOps architecture.

## Sync Wave Strategy

We've implemented a phased deployment approach using ArgoCD sync waves to ensure proper dependency resolution during the Kubeflow deployment process. The sync waves are ordered as follows:

| Sync Wave | Application | Purpose |
|-----------|-------------|---------|
| -2 | kubeflow-crds | Installs all required CRDs first |
| -1 | kubeflow-cert-manager | Deploys cert-manager components |
| 0 | kubeflow-infrastructure | Sets up namespace and cert-manager resources |
| 1 | kubeflow | Deploys main Kubeflow components |

## Why Sync Waves Matter

1. **Dependency Resolution**: Many Kubeflow components depend on CRDs being available before they can be deployed. By using sync waves, we ensure these dependencies are met.

2. **Default Behavior**: Resources without an explicit sync wave annotation default to wave 0. This allows us to place prerequisites in negative waves and dependent components in positive waves.

3. **Failure Prevention**: Without sync waves, ArgoCD might try to deploy resources that depend on CRDs before those CRDs exist, leading to synchronization failures.

4. **Rollback Safety**: During rollbacks or deletions, ArgoCD processes resources in reverse order of sync waves, ensuring safe cleanup.

## Implementation Details

### Wave -2: CRDs
- Contains all Custom Resource Definitions required by Kubeflow
- Must be successfully deployed before any other components

### Wave -1: Cert Manager
- Deploys cert-manager in its own namespace
- Provides certificate management functionality needed by Kubeflow components

### Wave 0: Kubeflow Infrastructure
- Creates the Kubeflow namespace with proper labels
- Sets up cert-manager resources specific to Kubeflow (Issuers, Certificates)
- Prepares the environment for Kubeflow components

### Wave 1: Kubeflow Components
- Deploys the main Kubeflow applications and services
- Only runs after all prerequisites are successfully deployed

## Troubleshooting

If you encounter synchronization issues:

1. Check the ArgoCD UI to see which sync wave is failing
2. Verify that all CRDs are properly installed (sync wave -2)
3. Ensure cert-manager is running correctly (sync wave -1)
4. Look for specific error messages in the ArgoCD application logs

## Future Enhancements

This sync wave approach can be extended to include more granular waves for specific Kubeflow components if needed. For example:

- Wave 2: User-specific profiles
- Wave 3: Additional Kubeflow extensions
