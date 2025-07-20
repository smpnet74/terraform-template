# Kgateway API Implementation

This document describes the Gateway API implementation in the cluster using Kgateway, an open-source Envoy-powered implementation.

## Overview

The [Gateway API](https://gateway-api.sigs.k8s.io/) is a collection of resources that model service networking in Kubernetes. These resources - GatewayClass, Gateway, HTTPRoute, TCPRoute, etc. - aim to evolve Kubernetes service networking through expressive, extensible, and role-oriented interfaces.

Our implementation uses:
- Gateway API CRDs version v1.2.1
- Kgateway v2.0.3 as the Gateway controller implementation

## Components

### Dual CRD Architecture

This implementation uses a **dual CRD installation strategy** that follows Gateway API community best practices:

1. **Standard Gateway API CRDs** (v1.2.1)
2. **Kgateway-specific CRDs** (v2.0.3)

This separation ensures both **standard compatibility** and **vendor-specific functionality**.

### 1. Standard Gateway API CRDs

The core Gateway API Custom Resource Definitions are installed directly via kubectl to ensure we have the exact version (v1.2.1) required for standard compatibility:

**Resources Provided:**
- `gateways.gateway.networking.k8s.io` - Core Gateway resource
- `httproutes.gateway.networking.k8s.io` - HTTP routing rules
- `referencegrants.gateway.networking.k8s.io` - Cross-namespace access control
- `gatewayclasses.gateway.networking.k8s.io` - Gateway implementation configuration

**Why Separate Installation:**
- **Version Control**: Ensures exact Gateway API version compatibility
- **Vendor Neutrality**: Uses official Kubernetes Gateway API definitions
- **Portability**: Enables switching between different Gateway implementations
- **Stability**: Prevents conflicts between vendor CRDs and standard CRDs

### 2. Kgateway-Specific CRDs

The Kgateway-specific CRDs are installed via Helm chart to provide vendor-specific enhancements:

**Resources Provided:**
- `backends.gateway.kgateway.dev` - Advanced backend configuration
- `trafficpolicies.gateway.kgateway.dev` - Traffic management policies
- `gatewayparameters.gateway.kgateway.dev` - Kgateway-specific parameters
- `httplistenerpolicies.gateway.kgateway.dev` - HTTP listener policies

**Why Helm Installation:**
- **Vendor Extensions**: Provides Kgateway-specific advanced features
- **Version Alignment**: Matches Kgateway controller version (v2.0.3)
- **Lifecycle Management**: Helm manages installation, upgrades, and removal
- **Feature Enablement**: Unlocks advanced traffic policies and AI gateway capabilities

### 3. Kgateway Controller

[Kgateway](https://kgateway.dev/) is an open-source, Envoy-powered implementation of the Gateway API. It was previously known as Gloo and has been production-ready since 2019. Kgateway provides:

- An ingress/edge router for Kubernetes powered by Envoy
- An advanced API gateway with authentication, authorization, and rate limiting
- Support for the Gateway API specification
- AI gateway capabilities for securing LLM usage

### 4. Default Gateway

A default Gateway resource is created in the default namespace. This Gateway:
- Listens on ports 80 (HTTP) and 443 (HTTPS)
- Allows routes from all namespaces
- Uses TLS termination for HTTPS with Cloudflare Origin Certificates
- Uses both **standard Gateway API** and **Kgateway-specific features**

## Usage

### Creating Routes

To expose a service through the Gateway, create an HTTPRoute resource:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-route
  namespace: default
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
  hostnames:
  - "example.yourdomain.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: example-service
      port: 80
```

### TLS Configuration

The default Gateway is configured with Cloudflare Origin Certificates for TLS termination. This provides:

- **Wildcard Certificate**: Covers `*.yourdomain.com` and `yourdomain.com`
- **Cloudflare Integration**: Certificates managed directly through Cloudflare
- **Kubernetes Secret**: Certificate and private key stored as `default-gateway-cert` in the default namespace
- **Edge Security**: Additional DDoS protection and edge acceleration via Cloudflare proxying

The certificate files are stored locally in the `/certs` directory and loaded into Kubernetes as a TLS secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: default-gateway-cert
  namespace: default
type: kubernetes.io/tls
data:
  tls.crt: # Base64 encoded Cloudflare Origin Certificate
  tls.key: # Base64 encoded private key
```

**Note**: Cloudflare SSL/TLS mode should be set to "Full" to ensure end-to-end encryption between Cloudflare edge and your cluster.

## Architecture Benefits

### Standard Compatibility

Using standard Gateway API CRDs ensures:
- **Ecosystem Compatibility**: Works with any Gateway API conformant tooling
- **Vendor Independence**: Can migrate to other Gateway implementations (Istio, Envoy Gateway, etc.)
- **Standards Compliance**: Compatible with Gateway API specifications
- **Community Support**: Follows Kubernetes community standards and best practices

### Advanced Features

Kgateway-specific CRDs enable:
- **Traffic Policies**: Advanced routing, load balancing, and traffic management
- **Security Features**: Authentication, authorization, and rate limiting
- **AI Gateway**: Specialized features for LLM and AI workload management
- **Enterprise Features**: Advanced observability and operational capabilities

### Verification Commands

To verify both CRD sets are properly installed:

```bash
# Check standard Gateway API CRDs
kubectl get crd | grep "gateway.networking.k8s.io"

# Check Kgateway-specific CRDs  
kubectl get crd | grep "gateway.kgateway.dev"

# Verify versions
kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}'
helm list -n kgateway-system
```

## Migration from Traefik Ingress

To migrate from Traefik Ingress resources to Gateway API:

1. Identify existing Ingress resources
2. Create equivalent HTTPRoute resources
3. Test the new routes
4. Remove the old Ingress resources once confirmed working

Example migration:

```yaml
# Old Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: example.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```

```yaml
# New HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-route
  namespace: default
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
  hostnames:
  - "example.yourdomain.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: example-service
      port: 80
```

## HTTPRoute Examples for Current Services

### ArgoCD HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd-server-route
  namespace: argocd
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "argocd.yourdomain.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: argocd-server
      port: 80
      kind: Service
```

### Argo Workflows HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argo-workflows
  namespace: argo
spec:
  parentRefs:
    - name: default-gateway
      namespace: default
      kind: Gateway
  hostnames:
    - "argo-workflows.yourdomain.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: argo-workflows-server
          port: 2746
          kind: Service
```

### Grafana HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana-route
  namespace: istio-system
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "grafana.yourdomain.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: grafana
      port: 80
```

### Kiali HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kiali-route
  namespace: istio-system
spec:
  parentRefs:
  - name: default-gateway
    namespace: default
    kind: Gateway
  hostnames:
  - "kiali.yourdomain.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: kiali
      port: 20001
```

## Cross-Namespace Access with ReferenceGrant

When HTTPRoutes need to reference a Gateway in a different namespace, a ReferenceGrant is required:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-argo-to-default-gateway
  namespace: default
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: argo
  to:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: default-gateway
```

This grants permission for HTTPRoutes in the `argo` namespace to reference the `default-gateway` in the `default` namespace.

## References

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Kgateway Documentation](https://kgateway.dev/docs)
- [Kgateway GitHub Repository](https://github.com/kgateway-dev/kgateway)
- [Gateway API Concepts](https://gateway-api.sigs.k8s.io/concepts/api-overview/)
