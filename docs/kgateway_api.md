# Kgateway API Implementation

This document describes the Gateway API implementation in the cluster using Kgateway, an open-source Envoy-powered implementation.

## Overview

The [Gateway API](https://gateway-api.sigs.k8s.io/) is a collection of resources that model service networking in Kubernetes. These resources - GatewayClass, Gateway, HTTPRoute, TCPRoute, etc. - aim to evolve Kubernetes service networking through expressive, extensible, and role-oriented interfaces.

Our implementation uses:
- Gateway API CRDs version v2.0.2
- Kgateway as the Gateway controller implementation

## Components

### 1. Gateway API CRDs

The Gateway API Custom Resource Definitions (CRDs) are installed by the Kgateway Helm chart. This ensures we have compatible CRDs with our Kgateway implementation.

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
- Uses TLS termination for HTTPS with a wildcard certificate

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

The default Gateway is configured with a wildcard certificate managed by cert-manager. This certificate covers:
- `*.yourdomain.com`
- `yourdomain.com`

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

## References

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Kgateway Documentation](https://kgateway.dev/docs)
- [Kgateway GitHub Repository](https://github.com/kgateway-dev/kgateway)
- [Gateway API Concepts](https://gateway-api.sigs.k8s.io/concepts/api-overview/)
