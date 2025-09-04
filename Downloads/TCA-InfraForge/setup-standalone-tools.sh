#!/bin/bash
# TC Enterprise DevOps Platform™ - Standalone Tools Setup
# Create configurations for advanced tools

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }

# Create tools directory
TOOLS_DIR="tools"
mkdir -p "$TOOLS_DIR"

log "Setting up standalone advanced tools..."

# Create Jaeger configuration
cat > "$TOOLS_DIR/jaeger-standalone.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger-standalone
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:latest
        ports:
        - containerPort: 16686
        - containerPort: 14268
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-service
  namespace: default
spec:
  selector:
    app: jaeger
  ports:
  - port: 16686
    targetPort: 16686
  type: ClusterIP
EOF

# Create ArgoCD configuration
cat > "$TOOLS_DIR/argocd-standalone.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server-standalone
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: argocd-server
  template:
    metadata:
      labels:
        app: argocd-server
    spec:
      containers:
      - name: argocd-server
        image: argoproj/argocd:latest
        ports:
        - containerPort: 8080
        env:
        - name: ARGOCD_SERVER_INSECURE
          value: "true"
        - name: ARGOCD_ADMIN_PASSWORD
          value: "TCEnterprise2025!"
---
apiVersion: v1
kind: Service
metadata:
  name: argocd-service
  namespace: default
spec:
  selector:
    app: argocd-server
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
EOF

# Create ingress
cat > "$TOOLS_DIR/standalone-ingress.yaml" << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: standalone-tools-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - temitayocharles.online
    secretName: temitayocharles-tls
  rules:
  - host: jaeger.temitayocharles.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jaeger-service
            port:
              number: 16686
  - host: argocd.temitayocharles.online
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-service
            port:
              number: 8080
EOF

# Create deployment script
cat > "$TOOLS_DIR/deploy-tools.sh" << 'EOF'
#!/bin/bash
echo "🚀 Deploying TC Enterprise Advanced Tools"
echo "Applying configurations..."

kubectl apply -f jaeger-standalone.yaml
kubectl apply -f argocd-standalone.yaml
kubectl apply -f standalone-ingress.yaml

echo "✅ Tools deployed!"
echo "Access:"
echo "• Jaeger: https://jaeger.temitayocharles.online"
echo "• ArgoCD: https://argocd.temitayocharles.online"
EOF

chmod +x "$TOOLS_DIR/deploy-tools.sh"

success "Standalone tools setup complete!"
echo ""
echo "Created files in: $TOOLS_DIR"
echo "To deploy: ./tools/deploy-tools.sh"
