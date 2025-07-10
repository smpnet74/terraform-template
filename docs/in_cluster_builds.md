# In-Cluster Container Builds with Argo Workflows and Kaniko

This document outlines the architecture and usage of the in-cluster container build system, which uses Argo Workflows and Kaniko to create a Kubernetes-native CI/CD pipeline.

## Architecture

The build system consists of the following components:

- **Argo Workflows**: The core orchestration engine that runs the build and deploy pipeline. It is installed via a Helm chart managed by Terraform.
- **Kaniko**: A tool for building container images from a Dockerfile inside a Kubernetes container, without requiring a Docker daemon.
- **WorkflowTemplate**: A reusable template (`ci-build-template`) that defines the steps for building a container image and updating a Kubernetes manifest.
- **Kubernetes Secrets**: Two secrets are required:
    - `docker-config`: Stores credentials for your container registry.
    - `git-credentials`: Stores credentials for pushing changes to your Git repository.

## How it Works

1.  A developer pushes code to an application repository.
2.  A `Workflow` is manually triggered (or can be automated with webhooks) that uses the `ci-build-template`.
3.  The workflow clones the application source code.
4.  **Kaniko** builds a new container image, tags it with the short Git commit SHA, and pushes it to your container registry.
5.  The workflow then clones your Kubernetes manifests repository.
6.  It updates the relevant deployment manifest with the new image tag.
7.  The updated manifest is committed and pushed back to the repository.
8.  **ArgoCD** detects the change in the manifest repository and automatically deploys the new application version to the cluster.

## How to Use

### 1. Enable the Feature

In your `terraform.tfvars` file, set the `enable_argo_workflows` variable to `true`:

```hcl
enable_argo_workflows = true
```

### 2. Configure Secrets

You must manually update the placeholder secrets with your actual credentials.

- **Docker Registry Credentials**:
  Update the `docker-config` secret in `argo_workflows.tf` with your base64-encoded Docker Hub credentials.
  You can generate the token with:
  ```bash
  echo -n '{"auths":{"https://index.docker.io/v1/":{"auth":"'$(echo -n "<your-username>:<your-password>" | base64)'"}}}' | base64
  ```

- **Git Credentials**:
  Update the `git-credentials` secret in `argo_workflows.tf` with your Git username and a Personal Access Token (PAT).

### 3. Run Terraform

Apply the Terraform changes to deploy Argo Workflows and the related resources:

```bash
terraform apply -auto-approve
```

### 4. Access the UI

Once deployed, you can access the Argo Workflows UI at the URL provided in the `argo_workflows_url` Terraform output.

### 5. Trigger a Build

To trigger a build, you will need to submit a `Workflow` that references the `ci-build-template`. Here is an example YAML:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: my-app-build-
  namespace: argo
spec:
  workflowTemplateRef:
    name: ci-build-template
  arguments:
    parameters:
      - name: repo_url
        value: "github.com/your-org/your-app-repo.git"
      - name: image_name
        value: "your-docker-hub-username/your-app-image"
      - name: manifest_repo_url
        value: "github.com/your-org/your-manifests-repo.git"
      - name: manifest_file_path
        value: "path/to/your/deployment.yaml"
```

You can submit this workflow using `kubectl`:

```bash
kubectl apply -f your-workflow.yaml
```
