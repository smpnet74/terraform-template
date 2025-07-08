# Kubeflow cert-manager (sync wave -1)

# Create the cert-manager directory structure
resource "github_repository_file" "kubeflow_cert_manager_kustomization" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/cert-manager/kustomization.yaml"
  content    = <<-EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cert-manager

resources:
- namespace.yaml
- cert-manager-crds.yaml
- cert-manager-deployment.yaml
EOF
}

# Create the cert-manager namespace definition
resource "github_repository_file" "kubeflow_cert_manager_namespace" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/cert-manager/namespace.yaml"
  content    = <<-EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
EOF
}

# Create the cert-manager CRDs file
resource "github_repository_file" "kubeflow_cert_manager_crds" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/cert-manager/cert-manager-crds.yaml"
  content    = <<-EOF
# Cert Manager CRDs
# Source: https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
# Only the CRDs section

apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: certificaterequests.cert-manager.io
  labels:
    app: cert-manager
    app.kubernetes.io/name: cert-manager
    app.kubernetes.io/instance: cert-manager
    app.kubernetes.io/component: "controller"
spec:
  group: cert-manager.io
  names:
    kind: CertificateRequest
    listKind: CertificateRequestList
    plural: certificaterequests
    shortNames:
    - cr
    - crs
    singular: certificaterequest
    categories:
    - cert-manager
  scope: Namespaced
  versions:
  - name: v1
    subresources:
      status: {}
    additionalPrinterColumns:
    - jsonPath: .status.conditions[?(@.type=="Ready")].status
      name: Ready
      type: string
    - jsonPath: .spec.issuerRef.name
      name: Issuer
      type: string
    - jsonPath: .status.conditions[?(@.type=="Ready")].message
      name: Status
      type: string
    - jsonPath: .metadata.creationTimestamp
      description: CreationTimestamp is a timestamp representing the server time when
        this object was created. It is not guaranteed to be set in happens-before order
        across separate operations. Clients may not set this value. It is represented
        in RFC3339 form and is in UTC.
      name: Age
      type: date
    schema:
      openAPIV3Schema:
        description: A CertificateRequest is used to request a signed certificate from
          one of the configured issuers.
        type: object
        required:
        - spec
        properties:
          apiVersion:
            description: 'APIVersion defines the versioned schema of this representation
              of an object. Servers should convert recognized schemas to the latest
              internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources'
            type: string
          kind:
            description: 'Kind is a string value representing the REST resource this
              object represents. Servers may infer this from the endpoint the client
              submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds'
            type: string
          metadata:
            type: object
          spec:
            description: Desired state of the CertificateRequest resource.
            type: object
            required:
            - issuerRef
            - request
            properties:
              duration:
                description: The requested 'duration' (i.e. lifetime) of the Certificate.
                  This option may be ignored/overridden by some issuer types.
                type: string
              extra:
                description: Extra contains extra attributes of the user that created
                  the CertificateRequest. Populated by the cert-manager webhook on creation
                  and immutable.
                type: object
                additionalProperties:
                  type: array
                  items:
                    type: string
              groups:
                description: Groups contains group membership of the user that created
                  the CertificateRequest. Populated by the cert-manager webhook on creation
                  and immutable.
                type: array
                items:
                  type: string
                x-kubernetes-list-type: atomic
              isCA:
                description: IsCA will request to mark the certificate as valid for certificate
                  signing when submitting to the issuer. This will automatically add
                  the `cert sign` usage to the list of `usages`.
                type: boolean
              issuerRef:
                description: IssuerRef is a reference to the issuer for this CertificateRequest.  If
                  the 'kind' field is not set, or set to 'Issuer', an Issuer resource
                  with the given name in the same namespace as the CertificateRequest
                  will be used.  If the 'kind' field is set to 'ClusterIssuer', a ClusterIssuer
                  with the provided name will be used. The 'name' field in this stanza
                  is required at all times. The group field refers to the API group of
                  the issuer which defaults to 'cert-manager.io' if empty.
                type: object
                required:
                - name
                properties:
                  group:
                    description: Group of the resource being referred to.
                    type: string
                  kind:
                    description: Kind of the resource being referred to.
                    type: string
                  name:
                    description: Name of the resource being referred to.
                    type: string
              request:
                description: The PEM-encoded x509 certificate signing request to be submitted
                  to the CA for signing.
                type: string
                format: byte
              uid:
                description: UID contains the uid of the user that created the CertificateRequest.
                  Populated by the cert-manager webhook on creation and immutable.
                type: string
              usages:
                description: Usages is the set of x509 usages that are requested for
                  the certificate. If usages are set they cannot be changed once the
                  CertificateRequest is created. Defaults to `digital signature` and
                  `key encipherment` if not specified.
                type: array
                items:
                  description: 'KeyUsage specifies valid usage contexts for keys. See:
                    https://tools.ietf.org/html/rfc5280#section-4.2.1.3      https://tools.ietf.org/html/rfc5280#section-4.2.1.12
                    Valid KeyUsage values are as follows: "signing", "digital signature",
                    "content commitment", "key encipherment", "key agreement", "data
                    encipherment", "cert sign", "crl sign", "encipher only", "decipher
                    only", "any", "server auth", "client auth", "code signing", "email
                    protection", "s/mime", "ipsec end system", "ipsec tunnel", "ipsec
                    user", "timestamping", "ocsp signing", "microsoft sgc", "netscape
                    sgc"'
                  type: string
                  enum:
                  - signing
                  - digital signature
                  - content commitment
                  - key encipherment
                  - key agreement
                  - data encipherment
                  - cert sign
                  - crl sign
                  - encipher only
                  - decipher only
                  - any
                  - server auth
                  - client auth
                  - code signing
                  - email protection
                  - s/mime
                  - ipsec end system
                  - ipsec tunnel
                  - ipsec user
                  - timestamping
                  - ocsp signing
                  - microsoft sgc
                  - netscape sgc
                x-kubernetes-list-type: atomic
              username:
                description: Username contains the name of the user that created the
                  CertificateRequest. Populated by the cert-manager webhook on creation
                  and immutable.
                type: string
          status:
            description: Status of the CertificateRequest. This is set and managed automatically.
            type: object
            properties:
              ca:
                description: The PEM encoded x509 certificate of the signer, also known
                  as the CA (Certificate Authority). This is set on a best-effort basis
                  by different issuers. If not set, the CA is assumed to be unknown/not
                  available.
                type: string
                format: byte
              certificate:
                description: The PEM encoded x509 certificate resulting from the certificate
                  signing request. If not set, the CertificateRequest has either not
                  been completed or has failed. More information on failure can be found
                  by checking the `conditions` field.
                type: string
                format: byte
              conditions:
                description: List of status conditions to indicate the status of a CertificateRequest.
                  Known condition types are `Ready` and `InvalidRequest`.
                type: array
                items:
                  description: CertificateRequestCondition contains condition information
                    for a CertificateRequest.
                  type: object
                  required:
                  - status
                  - type
                  properties:
                    lastTransitionTime:
                      description: LastTransitionTime is the timestamp corresponding
                        to the last status change of this condition.
                      type: string
                      format: date-time
                    message:
                      description: Message is a human readable description of the details
                        of the last transition, complementing reason.
                      type: string
                    reason:
                      description: Reason is a brief machine readable explanation for
                        the condition's last transition.
                      type: string
                    status:
                      description: Status of the condition, one of (`True`, `False`,
                        `Unknown`).
                      type: string
                      enum:
                      - "True"
                      - "False"
                      - Unknown
                    type:
                      description: Type of the condition, known values are (`Ready`,
                        `InvalidRequest`, `Approved`, `Denied`).
                      type: string
                x-kubernetes-list-map-keys:
                - type
                x-kubernetes-list-type: map
              failureTime:
                description: FailureTime stores the time that this CertificateRequest
                  failed. This is used to influence garbage collection and back-off.
                type: string
                format: date-time
    served: true
    storage: true
EOF
}

# Create the cert-manager deployment file
resource "github_repository_file" "kubeflow_cert_manager_deployment" {
  count      = var.enable_kubeflow ? 1 : 0
  repository = var.github_repo_name
  file       = "kubeflow/cert-manager/cert-manager-deployment.yaml"
  content    = <<-EOF
# Cert Manager Deployment
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager
  namespace: cert-manager
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-manager
rules:
- apiGroups: ["cert-manager.io"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["secrets", "configmaps", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-manager
subjects:
- kind: ServiceAccount
  name: cert-manager
  namespace: cert-manager
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-manager
  namespace: cert-manager
  labels:
    app: cert-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cert-manager
  template:
    metadata:
      labels:
        app: cert-manager
    spec:
      serviceAccountName: cert-manager
      containers:
      - name: cert-manager
        image: quay.io/jetstack/cert-manager-controller:v1.13.3
        args:
        - --v=2
        - --cluster-resource-namespace=$(POD_NAMESPACE)
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
EOF
}

# ArgoCD Application for Kubeflow cert-manager
resource "kubectl_manifest" "kubeflow_cert_manager_app" {
  count     = var.enable_kubeflow ? 1 : 0
  yaml_body = <<-EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeflow-cert-manager
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  project: default
  source:
    repoURL: ${var.github_repo_url}
    path: kubeflow/cert-manager
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  dependsOn:
    - name: kubeflow-crds
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

  depends_on = [
    var.argocd_helm_release,
    github_repository_file.kubeflow_cert_manager_kustomization[0],
    github_repository_file.kubeflow_cert_manager_namespace[0],
    github_repository_file.kubeflow_cert_manager_crds[0],
    github_repository_file.kubeflow_cert_manager_deployment[0],
    kubectl_manifest.kubeflow_crds_app[0]
  ]
}
