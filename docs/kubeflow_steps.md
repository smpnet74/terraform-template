# Kubeflow Implementation Steps

This document outlines the step-by-step implementation plan for integrating Kubeflow into the existing Kubernetes cluster using GitOps principles with ArgoCD, as described in the Kubeflow PRD.

## Implementation Summary

**Current Status**: Repository and Terraform configuration complete

**Completed Tasks**:
- Researched Kubeflow manifests and determined the best approach for GitOps/ArgoCD integration
- Created the directory structure for Kubeflow in the GitOps repository
- Created base kustomization referencing upstream Kubeflow manifests
- Created overlay customizations for kgateway and ambient mesh integration
- Created `github_kubeflow.tf` to manage the GitOps repository structure
- Implemented sync wave approach for phased deployment (see `docs/kubeflow_sync_waves.md`)
- Created separate ArgoCD applications for CRDs, cert-manager, infrastructure, and main components
- Updated `argocd_applications.tf` to include the Kubeflow applications with proper dependencies
- Added DNS record for Kubeflow in `cloudflare_dns.tf`

**Next Steps**:
1. Apply Terraform changes to create the GitOps repository structure
2. Verify the repository structure is created correctly
3. Monitor ArgoCD UI for deployment progress in sync wave order:
   - First: CRDs (sync wave -2)
   - Second: cert-manager (sync wave -1)
   - Third: Infrastructure (sync wave 0)
   - Fourth: Main Kubeflow components (sync wave 1)
4. Validate each wave completes successfully before proceeding
5. Verify all Kubeflow components are deployed and healthy

**Implementation Approach**:
- Direct references to upstream Kubeflow manifests for maintainability
- Custom overlays for environment-specific configurations
- Integration with existing kgateway and ambient mesh
- Phased deployment using ArgoCD sync waves for dependency management
- Proper synchronization policies and retry options in ArgoCD
- GitOps-based cert-manager deployment instead of Helm

## Phase 0: Research and Preparation

- [x] Research Kubeflow manifests best suited for GitOps/ArgoCD
- [x] Identify required Kubeflow components for initial deployment
- [ ] Verify cluster resources meet Kubeflow requirements
- [x] Ensure ArgoCD is properly configured for Kubeflow deployment
- [x] Review existing kgateway and ambient mesh configurations

## Phase 1: Repository Setup

- [x] Create directory structure in GitOps repository for Kubeflow
  - [x] Create `kubeflow` directory in the GitOps repository
  - [x] Create `base` subdirectory
  - [x] Create `overlays/default` subdirectory
  - [x] Create `crds` subdirectory for CRDs (sync wave -2)
  - [x] Create `cert-manager` subdirectory for cert-manager (sync wave -1)
  - [x] Create `infrastructure` subdirectory for Kubeflow infrastructure (sync wave 0)
  - [x] Create `profiles` subdirectory

- [x] Create base Kubeflow configuration
  - [x] Create `base/kustomization.yaml` referencing upstream Kubeflow manifests
  - [x] Create `base/namespace.yaml` for Kubeflow namespace definition

- [x] Create sync wave implementation
  - [x] Create CRDs kustomization for sync wave -2
  - [x] Create cert-manager kustomization for sync wave -1
  - [x] Create infrastructure kustomization for sync wave 0
  - [x] Update ArgoCD applications with appropriate sync wave annotations
  - [x] Document sync wave approach in `docs/kubeflow_sync_waves.md`

- [x] Create overlay customizations
  - [x] Create `overlays/default/kustomization.yaml` with environment-specific customizations
  - [x] Create `overlays/default/gateway-config.yaml` for kgateway integration
  - [x] Create `overlays/default/patches` directory for ambient mesh integration

## Phase 2: Terraform Configuration

- [x] Create `github_kubeflow.tf` file
  - [x] Add GitHub repository resource for Kubeflow manifests
  - [x] Configure base kustomization referencing upstream Kubeflow manifests
  - [x] Configure overlay kustomization with customizations
  - [x] Add gateway configuration for kgateway integration
  - [x] Add patches for ambient mesh integration

- [x] Update `argocd_applications.tf` file
  - [x] Add Kubeflow Application in ArgoCD
  - [x] Configure synchronization policy and retry options
  - [x] Set up dependencies to ensure proper deployment order
  - [x] Add DNS record for Kubeflow
  - [x] Add HTTPRoute for kgateway integration

## Phase 3: Deployment and Integration

- [ ] Apply Terraform changes to create GitOps repository structure
  - [ ] Run `terraform apply` to create repository structure
  - [ ] Verify repository structure is created correctly

- [ ] Deploy Kubeflow via ArgoCD
  - [ ] Apply ArgoCD Application for Kubeflow
  - [ ] Monitor ArgoCD UI for deployment progress
  - [ ] Verify all Kubeflow components are deployed successfully

- [ ] Configure kgateway integration
  - [ ] Apply HTTPRoute resources for Kubeflow
  - [ ] Verify Kubeflow is accessible through kgateway

- [ ] Configure ambient mesh integration
  - [ ] Apply namespace labels for ambient mesh
  - [ ] Verify Kubeflow services are properly integrated with ambient mesh

## Phase 4: Validation and Testing

- [ ] Verify Kubeflow components deployment
  - [ ] Check all pods are running in the Kubeflow namespace
  - [ ] Verify CRDs are properly installed

- [ ] Test access through kgateway
  - [ ] Access Kubeflow dashboard through configured hostname
  - [ ] Verify authentication flow works correctly

- [ ] Validate ambient mesh integration
  - [ ] Verify traffic flows correctly through ambient mesh
  - [ ] Check for any service mesh related errors

- [ ] Test core functionality
  - [ ] Create a test notebook
  - [ ] Test notebook execution
  - [ ] Test volume management
  - [ ] Test Tensorboard integration

## Phase 5: Documentation and Handover

- [ ] Document the implementation
  - [ ] Update README with Kubeflow information
  - [ ] Document access methods and URLs
  - [ ] Document resource requirements and limitations

- [ ] Create user guides
  - [ ] Create guide for creating and managing notebooks
  - [ ] Create guide for managing Kubeflow profiles
  - [ ] Create guide for troubleshooting common issues

## Future Enhancements (Post-Initial Deployment)

- [ ] Add KServe for model serving
  - [ ] Add KServe controller and CRDs
  - [ ] Configure integration with ambient mesh
  - [ ] Set up model storage with appropriate PVCs

- [ ] Add Kubeflow Pipelines
  - [ ] Add pipeline components and CRDs
  - [ ] Configure artifact storage
  - [ ] Set up integration with notebooks

- [ ] Add Katib for hyperparameter tuning
  - [ ] Add Katib controller and CRDs
  - [ ] Configure integration with pipelines

- [ ] Add Elyra for notebook-based pipelines
  - [ ] Add Elyra components
  - [ ] Configure integration with Kubeflow Pipelines

- [ ] Implement advanced configurations
  - [ ] Set up authentication integration (OIDC/OAuth2)
  - [ ] Configure resource optimization (node selectors, autoscaling)
  - [ ] Set up monitoring and logging integration
  - [ ] Implement backup and disaster recovery procedures
