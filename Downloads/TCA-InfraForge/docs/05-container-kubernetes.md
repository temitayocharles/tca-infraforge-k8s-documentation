# 🐳 Chapter 5: Container & Kubernetes

## 🎯 Learning Objectives
By the end of this chapter, you'll understand:
- How to set up Docker environments for development and production
- KIND cluster configuration and management
- Kubernetes resource deployment and scaling
- High availability patterns and best practices

**⏱️ Time to Complete:** 25-30 minutes  
**💡 Difficulty:** Intermediate  
**🎯 Prerequisites:** Basic understanding of containers and Kubernetes concepts

---

## 🌟 Container & Kubernetes Fundamentals

TCA InfraForge leverages **Docker** for containerization and **Kubernetes** for orchestration, providing a robust foundation for enterprise applications. This chapter covers the essential container and Kubernetes patterns used throughout the platform.

### Why Docker + Kubernetes?
- **🐳 Portability**: Consistent environments across development, staging, and production
- **📦 Scalability**: Horizontal scaling with Kubernetes
- **🔄 Reliability**: Self-healing containers and automated rollouts
- **🔒 Security**: Isolated environments with resource limits
- **⚡ Performance**: Optimized resource utilization

**Real-world analogy:** Docker containers are like shipping containers - they standardize how applications are packaged and transported, while Kubernetes is the port authority that manages where and how they're deployed!

---

## 🐳 Docker Environment Setup

### Development Environment

#### 1. Install Docker Desktop
```bash
# macOS with Homebrew
brew install --cask docker

# Or download from https://www.docker.com/products/docker-desktop

# Start Docker Desktop
open -a Docker
```

#### 2. Configure Docker for Development
```bash
# Create Docker configuration
mkdir -p ~/.docker

# Development daemon configuration
cat > ~/.docker/daemon.json << EOF
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart Docker
docker system prune -a --volumes
```

#### 3. Build Development Images
```bash
# Build all service images
docker build -t tca-infraforge/api:latest -f Dockerfile.api .
docker build -t tca-infraforge/backend:latest -f Dockerfile.backend .
docker build -t tca-infraforge/frontend:latest -f Dockerfile.frontend .

# Build with buildkit for faster builds
DOCKER_BUILDKIT=1 docker build -t tca-infraforge/api:latest -f Dockerfile.api .

# Multi-platform builds (for Apple Silicon + Intel)
docker buildx create --use --name multi-platform
docker buildx build --platform linux/amd64,linux/arm64 -t tca-infraforge/api:latest -f Dockerfile.api --push .
```

### Production Environment

#### Optimized Production Dockerfile
```dockerfile
# Dockerfile.api (Production)
FROM python:3.11-slim as base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Start application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### Multi-Stage Build for Optimization
```dockerfile
# Dockerfile.backend (Multi-stage)
FROM node:18-alpine as builder

# Install dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Build application
COPY . .
RUN npm run build

# Production stage
FROM node:18-alpine as production

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

# Copy built application
WORKDIR /app
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

# Switch to non-root user
USER nextjs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/api/health || exit 1

# Start with dumb-init
ENTRYPOINT ["dumb-init", "--"]
CMD ["npm", "start"]
```

#### Security Best Practices
```dockerfile
# Security-optimized Dockerfile
FROM ubuntu:22.04

# Avoid running as root
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Update packages and install security updates
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create app directory with correct permissions
RUN mkdir -p /app && chown -R appuser:appuser /app
WORKDIR /app

# Copy and set permissions for app files
COPY --chown=appuser:appuser . /app/

# Drop all capabilities and run as non-root
USER appuser

# Use exec form for proper signal handling
CMD ["./myapp"]
```

---

## 🚢 KIND Cluster Management

### KIND Configuration

#### Basic KIND Configuration
```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    extraPortMappings:
    - containerPort: 80
      hostPort: 80
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      protocol: TCP
    - containerPort: 30000
      hostPort: 30000
      protocol: TCP
```

#### High Availability KIND Configuration
```yaml
# kind-ha-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    extraPortMappings:
    - containerPort: 80
      hostPort: 80
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      protocol: TCP
    - containerPort: 30000
      hostPort: 30000
      protocol: TCP
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
```

#### Development KIND Configuration
```yaml
# kind-dev-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
    extraPortMappings:
    - containerPort: 80
      hostPort: 8080
      protocol: TCP
    - containerPort: 443
      hostPort: 8443
      protocol: TCP
    - containerPort: 30000
      hostPort: 30000
      protocol: TCP
    # Development ports
    - containerPort: 3000
      hostPort: 3000
      protocol: TCP
    - containerPort: 8000
      hostPort: 8000
      protocol: TCP
```

### KIND Cluster Operations

#### Create and Manage Clusters
```bash
# Create development cluster
kind create cluster --name tca-dev --config kind-dev-config.yaml

# Create production-like cluster
kind create cluster --name tca-prod --config kind-ha-config.yaml

# List all clusters
kind get clusters

# Get cluster info
kubectl cluster-info --context kind-tca-dev

# Switch between clusters
kubectl config use-context kind-tca-dev
kubectl config use-context kind-tca-prod
```

#### Load Docker Images into KIND
```bash
# Load images into KIND cluster
kind load docker-image tca-infraforge/api:latest --name tca-dev
kind load docker-image tca-infraforge/backend:latest --name tca-dev
kind load docker-image tca-infraforge/frontend:latest --name tca-dev

# Load all images at once
docker images | grep tca-infraforge | awk '{print $1 ":" $2}' | \
xargs -I {} kind load docker-image {} --name tca-dev
```

#### Cluster Maintenance
```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# View cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check cluster logs
kind export logs ./kind-logs --name tca-dev

# Clean up cluster
kind delete cluster --name tca-dev

# Reset and recreate
kind delete clusters --all
kind create cluster --name tca-dev --config kind-dev-config.yaml
```

---

## ☸️ Kubernetes Resource Management

### Core Resource Types

#### Deployments
```yaml
# backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tca-backend
  namespace: tca-infraforge
  labels:
    app: tca-backend
    component: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: tca-backend
  template:
    metadata:
      labels:
        app: tca-backend
        component: backend
    spec:
      containers:
      - name: backend
        image: tca-infraforge/backend:latest
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: tca-database-secret
              key: database-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        volumeMounts:
        - name: config-volume
          mountPath: /app/config
      volumes:
      - name: config-volume
        configMap:
          name: tca-backend-config
```

#### Services
```yaml
# backend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: tca-backend-service
  namespace: tca-infraforge
  labels:
    app: tca-backend
    component: backend
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
  selector:
    app: tca-backend
```

#### ConfigMaps and Secrets
```yaml
# backend-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tca-backend-config
  namespace: tca-infraforge
data:
  config.yaml: |
    server:
      port: 8000
      host: 0.0.0.0
    database:
      pool_size: 10
      max_overflow: 20
    logging:
      level: INFO
      format: json
    features:
      enable_metrics: true
      enable_tracing: true

# backend-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: tca-database-secret
  namespace: tca-infraforge
type: Opaque
data:
  # Base64 encoded values
  database-url: cG9zdGdyZXM6Ly91c2VyOnBhc3NAZGI6NTQzMi90Y2EtZGI=
  redis-url: cmVkaXM6Ly9yZWRpczowMDAw
  jwt-secret: eW91ci1qd3Qtc2VjcmV0LWtleS1oZXJl
```

### Advanced Resource Patterns

#### Horizontal Pod Autoscaler
```yaml
# backend-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: tca-backend-hpa
  namespace: tca-infraforge
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: tca-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Max
```

#### Pod Disruption Budget
```yaml
# backend-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: tca-backend-pdb
  namespace: tca-infraforge
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: tca-backend
```

#### Network Policies
```yaml
# backend-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tca-backend-network-policy
  namespace: tca-infraforge
spec:
  podSelector:
    matchLabels:
      app: tca-backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: tca-frontend
    - podSelector:
        matchLabels:
          app: tca-api-gateway
    ports:
    - protocol: TCP
      port: 8000
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: tca-database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: tca-redis
    ports:
    - protocol: TCP
      port: 6379
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

---

## 🚀 Deployment Strategies

### Rolling Updates
```yaml
# Rolling update deployment
kubectl set image deployment/tca-backend backend=tca-infraforge/backend:v2.0.0
kubectl rollout status deployment/tca-backend

# Rollback if needed
kubectl rollout undo deployment/tca-backend
kubectl rollout undo deployment/tca-backend --to-revision=2
```

### Blue-Green Deployment
```yaml
# Create blue deployment (current)
kubectl apply -f backend-blue.yaml

# Create green deployment (new version)
kubectl apply -f backend-green.yaml

# Switch service to green
kubectl patch service tca-backend-service -p '{"spec":{"selector":{"version":"green"}}}'

# Verify green deployment
kubectl get pods -l version=green

# Remove blue deployment after verification
kubectl delete deployment tca-backend-blue
```

### Canary Deployment
```yaml
# Deploy canary version
kubectl apply -f backend-canary.yaml

# Gradually increase traffic (using Istio or similar)
kubectl apply -f virtual-service-canary.yaml

# Monitor metrics
kubectl get pods -l version=canary
kubectl logs -l version=canary

# Scale up canary if successful
kubectl scale deployment tca-backend-canary --replicas=5

# Switch all traffic to canary
kubectl patch service tca-backend-service -p '{"spec":{"selector":{"version":"canary"}}}'
```

---

## 📊 Monitoring and Health Checks

### Resource Monitoring
```bash
# Monitor pod resources
kubectl top pods
kubectl top nodes

# Check resource usage
kubectl describe pod tca-backend-12345
kubectl get pod tca-backend-12345 -o yaml | grep -A 10 resources

# View events
kubectl get events --field-selector involvedObject.name=tca-backend-12345
```

### Health Check Configuration
```yaml
# Comprehensive health checks
apiVersion: v1
kind: Pod
metadata:
  name: tca-backend-health-pod
spec:
  containers:
  - name: backend
    image: tca-infraforge/backend:latest
    ports:
    - containerPort: 8000
    livenessProbe:
      httpGet:
        path: /health/live
        port: 8000
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /health/ready
        port: 8000
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
    startupProbe:
      httpGet:
        path: /health/startup
        port: 8000
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 5
      failureThreshold: 30
```

### Log Aggregation
```bash
# View pod logs
kubectl logs -f deployment/tca-backend

# View logs from specific container
kubectl logs -f deployment/tca-backend -c backend

# View logs with timestamps
kubectl logs -f deployment/tca-backend --timestamps

# Search logs for errors
kubectl logs deployment/tca-backend | grep ERROR

# Export logs for analysis
kubectl logs deployment/tca-backend > backend-logs.txt
```

---

## 🔧 Troubleshooting Common Issues

### Container Issues

#### Image Pull Errors
```bash
# Check image status
kubectl describe pod tca-backend-12345 | grep -A 10 "Containers"

# Check image pull secrets
kubectl get secrets -n tca-infraforge

# Verify image exists
docker pull tca-infraforge/backend:latest

# Check registry access
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_TOKEN
```

#### Resource Constraints
```bash
# Check resource usage
kubectl top pods
kubectl top nodes

# Describe pod for resource issues
kubectl describe pod tca-backend-12345

# Adjust resource limits
kubectl patch deployment tca-backend --type='json' -p='[{
  "op": "replace",
  "path": "/spec/template/spec/containers/0/resources/limits/memory",
  "value": "1Gi"
}]'
```

### Kubernetes Issues

#### Pod Scheduling Problems
```bash
# Check pod status
kubectl get pods -o wide

# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod tca-backend-12345

# Check taints and tolerations
kubectl get nodes -o jsonpath='{.items[*].spec.taints}'
```

#### Service Discovery Issues
```bash
# Check service endpoints
kubectl get endpoints tca-backend-service

# Test service DNS resolution
kubectl run test-pod --image=busybox --rm -it -- nslookup tca-backend-service

# Check service configuration
kubectl describe service tca-backend-service
```

---

## 📋 Best Practices

### Container Best Practices
- **🔒 Use non-root users**: Always run containers as non-root
- **📦 Minimize image size**: Use multi-stage builds and minimal base images
- **🏷️ Label consistently**: Use consistent labeling for organization
- **🔍 Health checks**: Implement proper liveness and readiness probes
- **📊 Resource limits**: Set appropriate CPU and memory limits
- **🔐 Secrets management**: Never bake secrets into images

### Kubernetes Best Practices
- **🏷️ Resource labeling**: Consistent labeling for all resources
- **🔄 Rolling updates**: Use rolling updates for zero-downtime deployments
- **📊 Monitoring**: Implement comprehensive monitoring and alerting
- **🔒 Security**: Use network policies and RBAC
- **📈 Scaling**: Implement HPA for automatic scaling
- **💾 Backup**: Regular backups of persistent data

### Development Best Practices
- **🐳 Local development**: Use KIND for local Kubernetes development
- **🔄 Hot reloading**: Enable hot reloading for faster development
- **🧪 Testing**: Comprehensive testing including integration tests
- **📝 Documentation**: Document all custom resources and configurations
- **🔄 CI/CD**: Automated testing and deployment pipelines

---

## 📚 Summary

Mastering containers and Kubernetes is essential for modern application deployment. TCA InfraForge provides a solid foundation with:

- **🐳 Docker**: Optimized containerization with security best practices
- **🚢 KIND**: Local Kubernetes development with production-like clusters
- **☸️ Kubernetes**: Comprehensive resource management and scaling
- **📊 Monitoring**: Full observability with health checks and logging
- **🔧 Troubleshooting**: Systematic approach to common issues

### Key Takeaways
1. **Containerization**: Docker provides consistent, portable environments
2. **Orchestration**: Kubernetes manages complex deployments at scale
3. **Monitoring**: Health checks and logging are crucial for reliability
4. **Security**: Implement least privilege and network segmentation
5. **Scaling**: Use HPA and rolling updates for seamless scaling

---

## 🎯 What's Next?

Now that you understand container and Kubernetes fundamentals, you're ready to:

1. **[🌐 Networking & Ingress](./06-networking-ingress.md)** - Configure external access and load balancing
2. **[📊 Monitoring & Observability](./07-monitoring-observability.md)** - Set up comprehensive monitoring
3. **[🚀 Enterprise Applications](./08-enterprise-applications.md)** - Deploy your applications

**💡 Pro Tip:** Start with KIND for local development, then scale to production clusters. Always implement health checks and resource limits for production deployments!

---

*Thank you for learning about TCA InfraForge's container and Kubernetes foundation! This knowledge will serve you well in building scalable, reliable enterprise applications.* 🚀
