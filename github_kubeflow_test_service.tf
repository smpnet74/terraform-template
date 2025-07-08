# GitHub repository file for a test service to validate the Kubeflow gateway

resource "github_repository_file" "kubeflow_test_service" {
  repository = github_repository.argocd_apps.name
  file       = "kubeflow/infrastructure/test-service.yaml"
  content    = <<-EOF
apiVersion: v1
kind: Service
metadata:
  name: kubeflow-dashboard
  namespace: kubeflow
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    app: kubeflow-test
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubeflow-test
  namespace: kubeflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kubeflow-test
  template:
    metadata:
      labels:
        app: kubeflow-test
    spec:
      containers:
      - name: nginx
        image: nginx:stable
        ports:
        - containerPort: 8080
          name: http
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-test-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-test-config
  namespace: kubeflow
data:
  default.conf: |
    server {
        listen 8080;
        server_name _;
        
        location / {
            add_header Content-Type text/html;
            return 200 '<html><body><h1>Kubeflow Gateway Test</h1><p>The gateway is working correctly!</p></body></html>';
        }
    }
EOF

  depends_on = [github_repository.argocd_apps]
}
