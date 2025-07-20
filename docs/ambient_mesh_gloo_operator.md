# Ambient Mesh with Gloo Operator

This document explains the integration of Istio Ambient Mesh using the Gloo Operator in our Kubernetes cluster.

## Overview

Ambient Mesh is installed using the Gloo Operator, which simplifies the installation and management of Istio components. The operator translates minimal configuration in a ServiceMeshController custom resource into a managed Istio experience, reducing both the configuration required and the overhead needed to manage Istio resources.

## Architecture Components

1. **Gloo Operator**: Manages the lifecycle of Istio components
2. **ServiceMeshController**: Custom resource that defines the Istio installation
3. **Istio Components**:
   - istiod: Control plane (2 replicas)
   - istio-cni-node: CNI plugin for traffic interception
   - ztunnel: Ambient data plane proxy

## Integration with Cilium CNI on K3s

The Ambient Mesh configuration is specifically designed to work with Cilium CNI on K3s:

1. **K3s Platform Configuration**: Explicitly set for K3s compatibility
   - `global.platform: k3s`

2. **CNI Chaining**: Istio CNI is configured as a chained plugin alongside Cilium
   - `cni.chained: true`
   - `cni.ambient: true`
   - `cni.cniBinDir: /opt/cni/bin`
   - `cni.cniConfDir: /etc/cni/net.d`
   - `cni.profile: ambient`

3. **Cilium Configuration**: Cilium is configured with `cni.exclusive: false` to allow chaining with Istio CNI

4. **eBPF Redirection**: Ambient Mesh uses eBPF for traffic redirection
   - `ambient.redirectMode: ebpf`

5. **Interception Mode**: Set to NONE to use external CNI
   - `meshConfig.defaultConfig.interceptionMode: NONE`

6. **Ambient Mode**: Enabled in istiod
   - `PILOT_ENABLE_AMBIENT: true`

## Installation Order

1. Kubernetes Cluster with Cilium CNI
2. Gloo Operator in `gloo-operator` namespace
3. ServiceMeshController resource that deploys:
   - Gateway API CRDs
   - Istio base components
   - istiod control plane
   - CNI node agent
   - ztunnel on each node

## Verification

To verify the installation:

```bash
# Check the status of the ServiceMeshController
kubectl describe servicemeshcontroller managed-istio

# Check the status of the Istio pods
kubectl get pods -n istio-system
```

When the mesh is successfully installed, the Phase in the ServiceMeshController status will read `SUCCEEDED`.

### Comprehensive Health Check

Use this one-liner to get a complete health check of your Ambient Mesh installation:

```bash
kubectl get servicemeshcontroller managed-istio -o jsonpath='{.status.phase}' && echo " | Pods:" && kubectl get pods -n istio-system --no-headers | awk '{print $1 ": " $2 " " $3}' | sort && echo "| CNI Status:" && kubectl get daemonset -n istio-system istio-cni-node -o jsonpath='{.status.numberReady}/{.status.desiredNumberScheduled}' && echo " | Ztunnel Status:" && kubectl get daemonset -n istio-system ztunnel -o jsonpath='{.status.numberReady}/{.status.desiredNumberScheduled}'
```

This command will show:
1. Overall ServiceMeshController status
2. All pods in the istio-system namespace with their ready state
3. CNI DaemonSet readiness (showing ready/total nodes)
4. Ztunnel DaemonSet readiness (showing ready/total nodes)

## Upgrading

To upgrade Ambient Mesh, simply update the `version` field in the ServiceMeshController resource. The operator will perform a rolling upgrade of all components. No application restarts are required due to the nature of Ambient Mesh.


## References

- [Ambient Mesh Gloo Operator Documentation](https://ambientmesh.io/docs/setup/gloo-operator/)
- [Gloo Mesh Documentation](https://docs.solo.io/gloo-mesh/main/istio/ambient/install/operator/)
