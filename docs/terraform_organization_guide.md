# Terraform Project Organization Guide

## Overview

This document outlines a recommended organization structure for the terraform-template project to improve maintainability, scalability, and alignment with the architecture goals. The structure is designed to support the evolution of the Kubernetes cluster architecture, including:

1. Application building-blocks (Dapr)
2. General ingress/gateway (Gateway API ↔ web traffic) Kgateway
3. AI Gateway (Gateway API ↔ LLM traffic) Kgateway
4. Service mesh (Ambient Mesh ↔ east-west mTLS, retries, telemetry)
5. Cilium as the CNI for networking and network policies

## Proposed Directory Structure

```
terraform-template/
├── README.md
├── main.tf                  # Main entry point with provider configurations
├── variables.tf             # All variable definitions
├── outputs.tf               # All outputs
├── terraform.tfvars.example # Example variables file
├── destroy.sh               # Utility script
│
├── modules/                 # Reusable modules
│   ├── cluster/             # Kubernetes cluster configuration
│   │   ├── main.tf          # Cluster creation and basic setup
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── firewall.tf      # Firewall rules for the cluster
│   │
│   ├── networking/          # Networking components
│   │   ├── cilium/          # Cilium CNI configuration
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── values.yaml
│   │   │
│   │   └── gateway/         # Gateway API and Kgateway
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── routes.tf    # HTTPRoute definitions
│   │
│   ├── observability/       # Monitoring and observability
│   │   └── hubble/          # Cilium Hubble configuration
│   │
│   ├── gitops/              # GitOps components
│   │   ├── argocd/          # ArgoCD configuration
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── applications.tf
│   │   │
│   │   └── github/          # GitHub repository configuration
│   │
│   └── cert-manager/        # Certificate management
│       ├── main.tf
│       ├── variables.tf
│       └── issuers.tf
│
├── environments/            # Environment-specific configurations
│   ├── dev/
│   │   └── terraform.tfvars
│   │
│   └── prod/
│       └── terraform.tfvars
│
└── docs/                    # Documentation
    ├── architecture/        # Architecture documentation
    │   └── goalsprd.md
    │
    └── operations/          # Operational documentation
        ├── certificate_troubleshooting.md
        ├── helm_cilium.md
        └── kgateway_api.md
```

## Implementation Guide

### Step 1: Create the Base Structure

Start by creating the directory structure and moving the core configuration files:

```bash
# Create directories
mkdir -p modules/{cluster,networking/{cilium,gateway},observability/hubble,gitops/{argocd,github},cert-manager}
mkdir -p environments/{dev,prod}
mkdir -p docs/{architecture,operations}

# Move existing docs
mv docs/goalsprd.md docs/architecture/
mv docs/{certificate_troubleshooting.md,helm_cilium.md,kgateway_api.md} docs/operations/
```

### Step 2: Refactor Core Files

Create the main entry point files:

1. **main.tf**: Consolidate provider configurations and module calls
2. **variables.tf**: Move all variable definitions here
3. **outputs.tf**: Consolidate all outputs

### Step 3: Implement Modules

#### Cluster Module

Move cluster-related configurations:

```bash
# Move cluster configuration
mv cluster.tf modules/cluster/main.tf
mv civo_firewall-cluster.tf civo_firewall-ingress.tf modules/cluster/firewall.tf
```

#### Networking Modules

Organize networking components:

```bash
# Move Cilium configuration
mv helm_cilium.tf modules/networking/cilium/main.tf
mv cilium_values.yaml modules/networking/cilium/values.yaml

# Move Gateway API configuration
mv kgateway_api.tf modules/networking/gateway/main.tf
mv kubernetes_ingress-argocd.tf modules/networking/gateway/routes.tf
```

#### GitOps Modules

Organize GitOps components:

```bash
# Move ArgoCD configuration
mv helm_argocd.tf modules/gitops/argocd/main.tf
mv argocd_applications.tf modules/gitops/argocd/applications.tf

# Move GitHub configuration
mv github.tf modules/gitops/github/main.tf
```

#### Certificate Management Module

Move cert-manager configurations:

```bash
# Move cert-manager configuration
mv helm_cert_manager.tf kubernetes_cert_manager.tf modules/cert-manager/main.tf
```

### Step 4: Update Module References

Update references between modules to use proper module inputs and outputs:

1. Create appropriate `variables.tf` and `outputs.tf` files in each module
2. Update references to use module outputs instead of direct resource references
3. Pass required variables to modules from the root module

### Step 5: Environment-Specific Configurations

Move environment-specific variables:

```bash
# Create environment-specific variable files
cp terraform.tfvars environments/dev/terraform.tfvars
# Customize for production
cp terraform.tfvars.example environments/prod/terraform.tfvars
```

## Benefits of This Structure

### 1. Modularity and Reusability

- Each component is isolated in its own module
- Modules can be reused across different environments or projects
- Changes to one component don't affect others

### 2. Maintainability

- Smaller, focused files are easier to understand and maintain
- Clear separation of concerns
- Easier to track changes in version control

### 3. Scalability

- New components can be added as new modules
- Environment-specific configurations can be managed separately
- Structure supports the planned architecture evolution

### 4. Collaboration

- Team members can work on different modules simultaneously
- Clear ownership of different components
- Better documentation and organization

### 5. Testing and Validation

- Modules can be tested independently
- Easier to implement automated testing
- Validation can be applied at the module level

## Future Considerations

As the architecture evolves, consider:

1. **Adding New Modules**:
   - Dapr module under application building-blocks
   - AI Gateway module under networking
   - Ambient Mesh module under networking

2. **Versioning Modules**:
   - Consider versioning modules as they stabilize
   - Use Git tags or semantic versioning

3. **Remote State Management**:
   - Implement remote state storage (e.g., S3, Terraform Cloud)
   - Configure state locking

4. **CI/CD Integration**:
   - Add CI/CD configurations for automated testing and deployment
   - Implement pre-commit hooks for validation

## Conclusion

This organization structure provides a solid foundation for managing the terraform-template project as it grows and evolves. By implementing this structure, the project will be more maintainable, scalable, and aligned with the architecture goals.
