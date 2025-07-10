# GitOps CI/CD Guide: ArgoCD + Argo Workflows

This guide explains how to use ArgoCD and Argo Workflows together to implement a complete GitOps CI/CD pipeline for building and deploying applications in your Kubernetes cluster.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [The Two-Repository Model](#the-two-repository-model)
3. [End-to-End Workflow](#end-to-end-workflow)
4. [Setting Up Your First Application](#setting-up-your-first-application)
5. [Argo Workflows Configuration](#argo-workflows-configuration)
6. [ArgoCD Configuration](#argocd-configuration)
7. [Webhook Integration](#webhook-integration)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## Architecture Overview

This infrastructure implements a modern GitOps CI/CD pipeline using:

- **ArgoCD**: Continuous Deployment (CD) - Watches your configuration repository and automatically deploys changes to Kubernetes
- **Argo Workflows**: Continuous Integration (CI) - Builds container images and updates deployment manifests
- **Argo Events**: Event-driven automation - Triggers workflows based on Git webhooks and other events

### Key Principles

1. **Separation of Concerns**: Source code and configuration are kept in separate repositories
2. **GitOps**: All changes are made through Git commits, providing full audit trails
3. **Declarative**: Infrastructure and applications are defined declaratively in YAML
4. **Automated**: From code commit to deployment with minimal manual intervention

## The Two-Repository Model

### Repository Structure

#### Application Source Repository (e.g., `github.com/yourorg/my-cool-app`)

**Contents:**
- Application source code (Python, Go, Node.js, etc.)
- `Dockerfile` for building container images
- Application-specific configuration files
- Development and testing scripts

**Purpose:**
- Where developers work daily
- Contains everything needed to build the application
- Triggers CI pipeline on code changes

**Example Structure:**
```
my-cool-app/
├── src/
│   ├── main.py
│   └── requirements.txt
├── Dockerfile
├── .github/
│   └── workflows/
├── tests/
└── README.md
```

#### Configuration Repository (`github.com/smpnet74/k8s-app-configs`)

**Contents:**
- Kubernetes manifests (Deployment, Service, HTTPRoute, etc.)
- Application-specific configurations
- Environment-specific values
- ArgoCD Application definitions

**Purpose:**
- Single source of truth for what runs in the cluster
- Managed by ArgoCD for automatic deployments
- Updated by CI pipeline when new images are built

**Example Structure:**
```
k8s-app-configs/
├── applications/
│   ├── my-cool-app/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── httproute.yaml
│   │   └── overlays/
│   │       ├── staging/
│   │       └── production/
│   └── another-app/
├── argocd-apps/
│   └── app-definitions/
└── shared/
    ├── namespaces/
    └── rbac/
```

## End-to-End Workflow

### Step 1: Developer Pushes Code

A developer merges a new feature into the main branch of the application repository:

```bash
git checkout main
git pull origin main
git merge feature-branch
git push origin main
```

### Step 2: Webhook Triggers Argo Workflow

The Git webhook sends a request to Argo Workflows, triggering the CI pipeline:

```json
{
  "repo_url": "github.com/yourorg/my-cool-app.git",
  "image_name": "your-registry/my-cool-app",
  "manifest_repo_url": "github.com/smpnet74/k8s-app-configs.git",
  "manifest_file_path": "applications/my-cool-app/base/deployment.yaml"
}
```

### Step 3: Argo Workflow Executes CI Pipeline

The workflow performs these tasks automatically:

1. **Clone Source Repository**: Downloads the application code
2. **Build Container Image**: Uses Kaniko to build the Docker image
3. **Push to Registry**: Uploads the image with a unique tag (e.g., commit SHA)
4. **Update Manifest**: Modifies the deployment YAML with the new image tag
5. **Commit Changes**: Pushes the updated manifest to the configuration repository

### Step 4: ArgoCD Executes CD Pipeline

ArgoCD detects the configuration change and deploys automatically:

1. **Detect Change**: Monitors the configuration repository for commits
2. **Compare State**: Compares Git state with cluster state
3. **Deploy Application**: Applies the new manifest to Kubernetes
4. **Monitor Health**: Ensures the deployment succeeds

## Setting Up Your First Application

### 1. Prepare Your Application Repository

Ensure your application repository has:

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY src/ .
EXPOSE 8080

CMD ["python", "main.py"]
```

### 2. Create Kubernetes Manifests

In the configuration repository (`k8s-app-configs`), create your application manifests:

**`applications/my-cool-app/base/deployment.yaml`:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-cool-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-cool-app
  template:
    metadata:
      labels:
        app: my-cool-app
    spec:
      containers:
      - name: my-cool-app
        image: your-registry/my-cool-app:latest  # This will be updated by CI
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
```

**`applications/my-cool-app/base/service.yaml`:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-cool-app
  namespace: default
spec:
  selector:
    app: my-cool-app
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

**`applications/my-cool-app/base/httproute.yaml`:**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-cool-app
  namespace: default
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "my-cool-app.yourdomain.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: my-cool-app
      port: 80
      kind: Service
```

### 3. Create ArgoCD Application

**`argocd-apps/my-cool-app.yaml`:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-cool-app
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/smpnet74/k8s-app-configs
    targetRevision: HEAD
    path: applications/my-cool-app/base
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## Argo Workflows Configuration

### CI Build Template

The infrastructure includes a pre-configured workflow template for building and deploying applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: ci-build-template
  namespace: argo
spec:
  entrypoint: build-and-push
  arguments:
    parameters:
      - name: repo_url
      - name: image_name
      - name: manifest_repo_url
      - name: manifest_file_path

  templates:
    - name: build-and-push
      steps:
        - - name: build
            template: kaniko-build
            arguments:
              parameters:
                - name: repo_url
                  value: "{{workflow.parameters.repo_url}}"
                - name: image_name
                  value: "{{workflow.parameters.image_name}}"

        - - name: update-manifest
            template: update-manifest
            arguments:
              parameters:
                - name: manifest_repo_url
                  value: "{{workflow.parameters.manifest_repo_url}}"
                - name: manifest_file_path
                  value: "{{workflow.parameters.manifest_file_path}}"
                - name: new_image
                  value: "{{steps.build.outputs.parameters.image_tag}}"

    - name: kaniko-build
      inputs:
        parameters:
          - name: repo_url
          - name: image_name
      outputs:
        parameters:
          - name: image_tag
            value: "{{inputs.parameters.image_name}}:{{workflow.outputs.parameters.git_sha_short}}"
      container:
        image: gcr.io/kaniko-project/executor:v1.9.0
        args:
          - "--dockerfile=./Dockerfile"
          - "--context={{inputs.parameters.repo_url}}#{{workflow.outputs.parameters.git_sha}}"
          - "--destination={{steps.build.outputs.parameters.image_tag}}"
        volumeMounts:
          - name: docker-config
            mountPath: /kaniko/.docker/
      volumes:
        - name: docker-config
          secret:
            secretName: docker-config

    - name: update-manifest
      inputs:
        parameters:
          - name: manifest_repo_url
          - name: manifest_file_path
          - name: new_image
      container:
        image: alpine/git:latest
        command: ["sh", "-c"]
        args:
          - |
            git config --global user.email "ci@example.com"
            git config --global user.name "CI Bot"
            git clone https://{{secrets.git-credentials.username}}:{{secrets.git-credentials.token}}@{{inputs.parameters.manifest_repo_url}} /tmp/manifests
            cd /tmp/manifests
            sed -i "s|image: .*|image: {{inputs.parameters.new_image}}|" "{{inputs.parameters.manifest_file_path}}"
            git add .
            git commit -m "Update image to {{inputs.parameters.new_image}}"
            git push
```

### Triggering Workflows

#### Manual Trigger

You can manually trigger a workflow from the Argo Workflows UI or CLI:

```bash
argo submit --from workflowtemplate/ci-build-template \
  --parameter repo_url=https://github.com/yourorg/my-cool-app.git \
  --parameter image_name=your-registry/my-cool-app \
  --parameter manifest_repo_url=github.com/smpnet74/k8s-app-configs.git \
  --parameter manifest_file_path=applications/my-cool-app/base/deployment.yaml
```

#### Automated Trigger with EventSources

Create an EventSource to listen for GitHub webhooks:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github-eventsource
  namespace: argo
spec:
  webhook:
    github:
      port: "12000"
      endpoint: /push
      method: POST
```

Create a Sensor to trigger workflows:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: github-sensor
  namespace: argo
spec:
  template:
    serviceAccountName: argo-events-sa
  dependencies:
  - name: github-dep
    eventSourceName: github-eventsource
    eventName: github
  triggers:
  - template:
      name: github-workflow-trigger
      argoWorkflow:
        operation: submit
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            metadata:
              generateName: github-ci-
            spec:
              workflowTemplateRef:
                name: ci-build-template
              arguments:
                parameters:
                - name: repo_url
                  value: "github.com/yourorg/my-cool-app.git"
                - name: image_name
                  value: "your-registry/my-cool-app"
                - name: manifest_repo_url
                  value: "github.com/smpnet74/k8s-app-configs.git"
                - name: manifest_file_path
                  value: "applications/my-cool-app/base/deployment.yaml"
```

## ArgoCD Configuration

### Application Access

ArgoCD is accessible at: `https://argocd.yourdomain.com`

To get the admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Adding Your Configuration Repository

1. Log in to ArgoCD UI
2. Go to Settings → Repositories
3. Click "Connect Repo"
4. Add your configuration repository URL: `https://github.com/smpnet74/k8s-app-configs`
5. Provide credentials if it's a private repository

### App-of-Apps Pattern

The infrastructure uses the app-of-apps pattern where a root application manages all other applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/smpnet74/k8s-app-configs
    targetRevision: HEAD
    path: argocd-apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Webhook Integration

### GitHub Webhook Setup

1. Go to your application repository settings
2. Navigate to Webhooks
3. Add a new webhook:
   - **Payload URL**: `https://argo-workflows.yourdomain.com/api/v1/events/argo/webhook`
   - **Content Type**: `application/json`
   - **Events**: Select "Push" events
   - **Active**: Checked

### Webhook Security

For production environments, implement webhook signature verification:

```yaml
# In your EventSource
spec:
  webhook:
    github:
      port: "12000"
      endpoint: /push
      method: POST
      secret:
        name: github-webhook-secret
        key: secret
```

## Troubleshooting

### Common Issues

#### 1. Workflow Fails to Build Image

**Symptoms**: Kaniko build step fails with permission errors

**Solution**: Check Docker registry credentials:
```bash
kubectl get secret docker-config -n argo -o yaml
```

Ensure the secret contains valid Docker registry credentials.

#### 2. Manifest Update Fails

**Symptoms**: Git push fails in update-manifest step

**Solution**: Verify Git credentials:
```bash
kubectl get secret git-credentials -n argo -o yaml
```

Ensure the Personal Access Token has repository write permissions.

#### 3. ArgoCD Doesn't Detect Changes

**Symptoms**: ArgoCD shows "Synced" but doesn't deploy new version

**Solutions**:
- Check repository webhook configuration
- Verify ArgoCD has access to the configuration repository
- Manual sync: Click "Sync" in ArgoCD UI

#### 4. HTTPRoute Not Working

**Symptoms**: Application not accessible via domain

**Solution**: Check Gateway and HTTPRoute status:
```bash
kubectl get gateway default-gateway -n default
kubectl get httproute my-cool-app -n default
kubectl describe httproute my-cool-app -n default
```

### Debugging Commands

```bash
# Check Argo Workflows
kubectl get workflows -n argo
kubectl logs -f <workflow-pod> -n argo

# Check ArgoCD Applications
kubectl get applications -n argocd
kubectl describe application my-cool-app -n argocd

# Check EventBus and Events
kubectl get eventbus -n argo
kubectl get eventsources -n argo
kubectl get sensors -n argo

# Check Gateway and Routes
kubectl get gateway -A
kubectl get httproute -A
```

## Best Practices

### 1. Repository Organization

- **Use consistent naming**: Follow kebab-case for application names
- **Organize by environment**: Use Kustomize overlays for different environments
- **Version your configurations**: Tag releases in your configuration repository

### 2. Security

- **Use least privilege**: Grant minimal necessary permissions to service accounts
- **Rotate credentials**: Regularly update Docker registry and Git credentials
- **Secure webhooks**: Use webhook secrets for signature verification

### 3. Image Management

- **Use semantic versioning**: Tag images with version numbers, not just commit SHAs
- **Implement image scanning**: Scan images for vulnerabilities before deployment
- **Clean up old images**: Implement image cleanup policies in your registry

### 4. Monitoring and Observability

- **Monitor workflow success**: Set up alerts for failed workflows
- **Track deployment metrics**: Monitor application health after deployments
- **Audit changes**: Use Git history for change tracking and rollbacks

### 5. Testing

- **Test in staging**: Deploy to staging environment before production
- **Implement health checks**: Use liveness and readiness probes
- **Automate testing**: Include test steps in your CI workflows

## Advanced Patterns

### Multi-Environment Deployments

Use Kustomize for environment-specific configurations:

```
applications/my-cool-app/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── staging/
    │   ├── kustomization.yaml
    │   └── replica-count.yaml
    └── production/
        ├── kustomization.yaml
        └── replica-count.yaml
```

### Rollback Strategies

ArgoCD supports automatic rollbacks:

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Blue-Green Deployments

Implement blue-green deployments using Argo Rollouts:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-cool-app
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: my-cool-app-active
      previewService: my-cool-app-preview
      autoPromotionEnabled: false
  selector:
    matchLabels:
      app: my-cool-app
  template:
    metadata:
      labels:
        app: my-cool-app
    spec:
      containers:
      - name: my-cool-app
        image: your-registry/my-cool-app:latest
```

This GitOps CI/CD pipeline provides a robust, scalable foundation for modern application development and deployment. The separation between CI (Argo Workflows) and CD (ArgoCD) ensures that each tool excels at what it does best, while the two-repository model provides clear separation of concerns between application code and deployment configuration.