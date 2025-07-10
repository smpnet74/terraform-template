# Kgateway API Implementation

This document describes the Gateway API implementation in the cluster using Kgateway, an open-source Envoy-powered implementation.

## Overview

The [Gateway API](https://gateway-api.sigs.k8s.io/) is a collection of resources that model service networking in Kubernetes. These resources - GatewayClass, Gateway, HTTPRoute, TCPRoute, etc. - aim to evolve Kubernetes service networking through expressive, extensible, and role-oriented interfaces.

Our implementation uses:
- Gateway API CRDs version v1.2.1
- Kgateway v2.0.3 as the Gateway controller implementation

## Components

### 1. Gateway API CRDs

The Gateway API Custom Resource Definitions (CRDs) are installed separately using kubectl to ensure we have the latest stable version (v1.2.1). These CRDs are then followed by Kgateway-specific CRDs via Helm chart.

### 2. Kgateway Controller

[Kgateway](https://kgateway.dev/) is an open-source, Envoy-powered implementation of the Gateway API. It was previously known as Gloo and has been production-ready since 2019. Kgateway provides:

- An ingress/edge router for Kubernetes powered by Envoy
- An advanced API gateway with authentication, authorization, and rate limiting
- Support for the Gateway API specification
- AI gateway capabilities for securing LLM usage

### 3. Default Gateway

A default Gateway resource is created in the default namespace. This Gateway:
- Listens on ports 80 (HTTP) and 443 (HTTPS)
- Allows routes from all namespaces
- Uses TLS termination for HTTPS with Cloudflare Origin Certificates

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
