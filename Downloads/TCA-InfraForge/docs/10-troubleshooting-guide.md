# 🔧 Chapter 10: Troubleshooting Guide

## 🏆 TC Enterprise DevOps Platform™

**Comprehensive Troubleshooting & Problem Resolution**

---

## 🚨 Common Issues & Solutions

### 🔴 **Critical Issues**

#### **1. Cluster Not Starting**
**Symptoms:**
- `kubectl get nodes` shows no nodes
- KIND cluster creation fails
- Docker containers not running

**Solutions:**

```bash
# Check Docker status
docker ps -a

# Verify Docker daemon
docker info

# Check KIND cluster status
kind get clusters

# Recreate cluster if needed
kind delete cluster --name tc-enterprise
kind create cluster --config kind-config.yaml

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

**Prevention:**
- Ensure Docker has sufficient resources (4GB RAM, 2 CPUs)
- Check available disk space: `df -h`
- Verify Docker Desktop is running (macOS)

#### **2. Application Pods Not Starting**
**Symptoms:**
- Pods stuck in `Pending` or `ContainerCreating` state
- `kubectl get pods` shows errors

**Diagnostic Commands:**
```bash
# Check pod status
kubectl get pods -A

# Get detailed pod information
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace> --previous

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top nodes
kubectl top pods
```

**Common Solutions:**
```bash
# Check node resources
kubectl describe node

# Check persistent volume claims
kubectl get pvc -A

# Verify service accounts
kubectl get serviceaccounts

# Check network policies
kubectl get networkpolicies
```

#### **3. Database Connection Issues**
**Symptoms:**
- Applications can't connect to PostgreSQL
- Connection timeout errors
- Authentication failures

**Troubleshooting:**
```bash
# Check database pod status
kubectl get pods -l app=postgres -n database

# Verify database service
kubectl get svc postgres -n database

# Test database connectivity from pod
kubectl exec -it <app-pod> -n <namespace> -- psql -h postgres -U tcuser -d tc_enterprise

# Check database logs
kubectl logs -l app=postgres -n database --tail=100

# Verify secrets
kubectl get secrets -n database
```

**Configuration Fix:**
```yaml
# Check database connection string in config
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: enterprise
data:
  DATABASE_URL: "postgresql://tcuser:password@postgres.database:5432/tc_enterprise"
```

---

## 🌐 Networking Issues

### **4. Ingress Not Working**
**Symptoms:**
- External access fails
- 404 or connection refused errors
- SSL certificate issues

**Diagnostic Steps:**
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Verify ingress resources
kubectl get ingress -A

# Check ingress logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Test internal service connectivity
kubectl exec -it <ingress-pod> -n ingress-nginx -- curl http://backend-service

# Verify SSL certificates
kubectl get certificates -A
```

**Common Fixes:**
```bash
# Restart ingress controller
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

# Check ingress class
kubectl get ingressclass

# Verify DNS resolution
nslookup tc-enterprise.local

# Test Cloudflare tunnel
cloudflared tunnel list
```

### **5. Service Mesh Issues**
**Symptoms:**
- Inter-service communication fails
- mTLS certificate errors
- Traffic routing problems

**Troubleshooting:**
```bash
# Check Istio components
kubectl get pods -n istio-system

# Verify service entries
kubectl get serviceentries

# Check destination rules
kubectl get destinationrules

# Test mTLS
kubectl exec -it <pod> -n <namespace> -- curl -v https://other-service:443

# Check sidecar injection
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].name}' | tr ' ' '\n' | grep istio-proxy
```

---

## 🔒 Security Issues

### **6. Authentication Failures**
**Symptoms:**
- Login attempts failing
- JWT token errors
- MFA setup issues

**Diagnostic Commands:**
```bash
# Check authentication service logs
kubectl logs -l app=auth-service --tail=50

# Verify JWT secrets
kubectl get secrets -l app=auth-service

# Test token validation
kubectl exec -it <auth-pod> -- node -e "
const jwt = require('jsonwebtoken');
const token = process.env.JWT_SECRET;
console.log('JWT Secret length:', token.length);
"

# Check Redis connectivity
kubectl exec -it <auth-pod> -- redis-cli ping
```

**Solutions:**
```bash
# Rotate JWT secrets
kubectl delete secret jwt-secret
kubectl create secret generic jwt-secret --from-literal=secret=$(openssl rand -base64 32)

# Restart authentication service
kubectl rollout restart deployment auth-service

# Clear Redis cache
kubectl exec -it redis-master -- redis-cli FLUSHALL
```

### **7. Authorization Issues**
**Symptoms:**
- Access denied errors
- RBAC permission failures
- Role assignment problems

**Troubleshooting:**
```bash
# Check user roles
kubectl get clusterrolebindings
kubectl get rolebindings -A

# Verify service account permissions
kubectl auth can-i list pods --as=system:serviceaccount:<namespace>:<serviceaccount>

# Check RBAC policies
kubectl get clusterroles
kubectl get roles -A

# Test permission
kubectl auth can-i create pods --as=<user>
```

---

## 📊 Monitoring Issues

### **8. Metrics Not Collecting**
**Symptoms:**
- Grafana dashboards empty
- Prometheus targets down
- Alerting not working

**Diagnostic Steps:**
```bash
# Check Prometheus status
kubectl get pods -n monitoring

# Verify service discovery
kubectl exec -it prometheus-0 -n monitoring -- wget -qO- http://localhost:9090/api/v1/targets

# Check Grafana logs
kubectl logs -l app=grafana -n monitoring

# Test metrics endpoints
kubectl exec -it <app-pod> -- curl http://localhost:8080/metrics

# Verify alertmanager
kubectl get pods -n monitoring -l app=alertmanager
```

**Common Fixes:**
```bash
# Restart monitoring stack
kubectl rollout restart deployment prometheus -n monitoring
kubectl rollout restart deployment grafana -n monitoring

# Update service monitors
kubectl apply -f monitoring/service-monitors.yaml

# Check configuration
kubectl get configmaps -n monitoring
```

### **9. Alerting Not Working**
**Symptoms:**
- No alerts received
- Email/Slack notifications failing
- Alert rules not triggering

**Troubleshooting:**
```bash
# Check alertmanager configuration
kubectl exec -it alertmanager-0 -n monitoring -- cat /etc/alertmanager/alertmanager.yml

# Verify alert rules
kubectl exec -it prometheus-0 -n monitoring -- wget -qO- http://localhost:9090/api/v1/rules

# Test alertmanager
kubectl port-forward alertmanager-0 9093:9093 -n monitoring
curl http://localhost:9093/api/v2/alerts

# Check notification channels
kubectl get secrets -n monitoring | grep alertmanager
```

---

## 💾 Storage Issues

### **10. Persistent Volume Problems**
**Symptoms:**
- PVC stuck in `Pending`
- Pod crashes due to storage issues
- Data persistence failures

**Diagnostic Commands:**
```bash
# Check PVC status
kubectl get pvc -A

# Describe PVC
kubectl describe pvc <pvc-name>

# Check PV status
kubectl get pv

# Verify storage class
kubectl get storageclass

# Check storage provisioner
kubectl get pods -n kube-system | grep storage
```

**Solutions:**
```bash
# Create storage class if missing
kubectl apply -f storage/storage-class.yaml

# Manually create PV
kubectl apply -f storage/persistent-volume.yaml

# Check node storage
kubectl describe node | grep -A 10 "Allocated resources"
```

### **11. Backup/Restore Issues**
**Symptoms:**
- Backup jobs failing
- Restore operations failing
- Data corruption

**Troubleshooting:**
```bash
# Check backup job status
kubectl get jobs -n backup

# Verify backup logs
kubectl logs -l job-name=<backup-job> -n backup

# Test restore process
kubectl apply -f backup/restore-job.yaml

# Check backup storage
kubectl get pvc -l app=backup -n backup
```

---

## ⚡ Performance Issues

### **12. High Resource Usage**
**Symptoms:**
- Pods using excessive CPU/Memory
- Node resource exhaustion
- Application slowdown

**Diagnostic Steps:**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods

# Get pod resource limits
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].resources}'

# Check for resource quotas
kubectl get resourcequotas -A

# Monitor specific pod
kubectl exec -it <pod> -- top

# Check for memory leaks
kubectl exec -it <pod> -- ps aux --sort=-%mem | head -10
```

**Optimization:**
```bash
# Update resource limits
kubectl apply -f k8s/resource-limits.yaml

# Enable vertical pod autoscaling
kubectl apply -f k8s/vpa.yaml

# Check for bottlenecks
kubectl get hpa -A
```

### **13. Slow Application Response**
**Symptoms:**
- High latency
- Timeout errors
- Database query slowness

**Performance Analysis:**
```bash
# Check application logs for slow queries
kubectl logs -l app=<app-name> --tail=100 | grep "slow\|timeout"

# Database performance
kubectl exec -it postgres-0 -- psql -c "SELECT * FROM pg_stat_activity;"

# Network latency
kubectl run nettest --image=busybox --rm -it -- wget -O- http://<service>

# Cache hit rate
kubectl exec -it redis-master -- redis-cli info stats
```

---

## 🔄 Deployment Issues

### **14. Rolling Update Failures**
**Symptoms:**
- Deployments stuck
- Rollback failures
- Pod disruption issues

**Troubleshooting:**
```bash
# Check deployment status
kubectl get deployments -A

# Describe deployment
kubectl describe deployment <deployment-name>

# Check rollout history
kubectl rollout history deployment/<deployment-name>

# View rollout status
kubectl rollout status deployment/<deployment-name>

# Check pod disruption budget
kubectl get pdb -A
```

**Recovery:**
```bash
# Pause rollout
kubectl rollout pause deployment/<deployment-name>

# Rollback to previous version
kubectl rollout undo deployment/<deployment-name>

# Force rollout
kubectl rollout restart deployment/<deployment-name>
```

### **15. Helm Chart Issues**
**Symptoms:**
- Helm install/upgrade fails
- Chart dependencies missing
- Values not applied

**Diagnostic Commands:**
```bash
# Check helm status
helm list -A

# Get release information
helm status <release-name> -n <namespace>

# Check helm history
helm history <release-name> -n <namespace>

# Validate chart
helm template <chart-name> <repo>/<chart> --values values.yaml

# Check dependencies
helm dependency list <chart-directory>
```

---

## ☁️ Cloud Integration Issues

### **16. Cloudflare Tunnel Problems**
**Symptoms:**
- Tunnel not connecting
- DNS propagation issues
- Certificate errors

**Troubleshooting:**
```bash
# Check tunnel status
cloudflared tunnel list

# Verify tunnel logs
tail -f /usr/local/var/log/cloudflared.log

# Test tunnel connectivity
curl -v https://tc-enterprise.local

# Check DNS records
dig tc-enterprise.local

# Restart tunnel service
brew services restart cloudflared
```

### **17. External Service Integration**
**Symptoms:**
- API calls failing
- Webhook delivery issues
- Third-party service errors

**Diagnostic Steps:**
```bash
# Test external connectivity
kubectl exec -it <pod> -- curl -v https://api.external-service.com

# Check DNS resolution
kubectl exec -it <pod> -- nslookup api.external-service.com

# Verify certificates
kubectl exec -it <pod> -- openssl s_client -connect api.external-service.com:443

# Check network policies
kubectl get networkpolicies -A
```

---

## 🐛 Debugging Tools

### **18. Advanced Debugging Techniques**

#### **Ephemeral Debug Containers**
```bash
# Debug running pod
kubectl debug <pod-name> -it --image=busybox --target=<container-name>

# Copy files from pod
kubectl cp <pod-name>:/path/to/file ./local-file

# Execute commands in pod
kubectl exec -it <pod-name> -- /bin/bash

# Port forward for local debugging
kubectl port-forward <pod-name> 8080:8080
```

#### **Network Debugging**
```bash
# Check network connectivity
kubectl run netdebug --image=busybox --rm -it -- nslookup kubernetes.default

# Test service DNS
kubectl run dnsdebug --image=busybox --rm -it -- nslookup <service-name>

# Check network policies
kubectl run netpoldebug --image=busybox --rm -it -- wget -qO- http://<service>
```

#### **Log Analysis**
```bash
# Stream logs
kubectl logs -f <pod-name> -c <container-name>

# Search logs for patterns
kubectl logs <pod-name> | grep "ERROR\|WARN"

# Export logs for analysis
kubectl logs <pod-name> > pod-logs.txt

# Check previous container logs
kubectl logs <pod-name> --previous
```

#### **Resource Debugging**
```bash
# Check resource limits
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].resources}'

# Monitor resource usage
kubectl top pods --containers

# Check for OOM kills
kubectl get pods -A | grep CrashLoopBackOff

# Analyze pod events
kubectl get events --field-selector involvedObject.name=<pod-name>
```

---

## 🚀 Automated Troubleshooting

### **19. Health Check Scripts**

```bash
#!/bin/bash
# comprehensive-health-check.sh

echo "🔍 TC Enterprise Health Check"
echo "================================"

# Cluster status
echo "📊 Cluster Status:"
kubectl get nodes
kubectl cluster-info

# Pod status
echo "🐳 Pod Status:"
kubectl get pods -A --no-headers | awk '$4 != "Running" {print}'

# Service status
echo "🌐 Service Status:"
kubectl get svc -A

# Ingress status
echo "🚪 Ingress Status:"
kubectl get ingress -A

# Database connectivity
echo "🗄️ Database Check:"
kubectl exec -it $(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U tcuser -d tc_enterprise -c "SELECT version();"

# Monitoring status
echo "📈 Monitoring Status:"
kubectl get pods -n monitoring

echo "✅ Health check complete"
```

### **20. Automated Recovery Scripts**

```bash
#!/bin/bash
# auto-recovery.sh

echo "🔧 Auto Recovery Started"

# Check cluster health
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Cluster unhealthy, recreating..."
    kind delete cluster --name tc-enterprise
    kind create cluster --config kind-config.yaml
fi

# Check critical pods
critical_pods=("postgres" "redis" "ingress-nginx")
for pod in "${critical_pods[@]}"; do
    if ! kubectl get pods -l app=$pod | grep -q Running; then
        echo "❌ $pod unhealthy, restarting..."
        kubectl rollout restart deployment $pod
    fi
done

# Check ingress
if ! kubectl get ingress | grep -q tc-enterprise; then
    echo "❌ Ingress missing, redeploying..."
    kubectl apply -f k8s/ingress.yaml
fi

echo "✅ Auto recovery complete"
```

---

## 📞 Support & Escalation

### **21. Support Resources**

#### **Internal Support**
- **Documentation**: Check this troubleshooting guide first
- **Logs**: Always collect relevant logs before escalating
- **Metrics**: Include monitoring data when reporting issues
- **Environment**: Note your OS, Docker version, Kubernetes version

#### **External Resources**
- **Kubernetes Issues**: [GitHub Issues](https://github.com/kubernetes/kubernetes/issues)
- **Docker Issues**: [Docker Forums](https://forums.docker.com/)
- **Cloudflare Issues**: [Cloudflare Status](https://www.cloudflarestatus.com/)
- **PostgreSQL Issues**: [PostgreSQL Mailing Lists](https://www.postgresql.org/list/)

#### **Community Support**
- **Stack Overflow**: Tag with `kubernetes`, `docker`, `postgresql`
- **Reddit**: r/kubernetes, r/docker, r/PostgreSQL
- **DevOps Forums**: Various DevOps communities

### **22. Issue Reporting Template**

```markdown
## Issue Report Template

**Issue Summary:**
[Brief description of the problem]

**Environment:**
- OS: [macOS version]
- Docker: [version]
- Kubernetes: [version]
- TC Enterprise: [version/tag]

**Symptoms:**
[Detailed description of what's happening]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Logs:**
```
[Paste relevant logs here]
```

**Diagnostic Output:**
```
[Paste kubectl describe, logs, etc.]
```

**Recent Changes:**
[Any recent deployments, configuration changes, etc.]

**Severity:**
- [ ] Critical (system down)
- [ ] High (major functionality broken)
- [ ] Medium (minor functionality broken)
- [ ] Low (cosmetic issue)
```

---

## 📚 Additional Resources

### 🔗 **Troubleshooting Links**

- **[Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)**
- **[Docker Troubleshooting](https://docs.docker.com/config/daemon/troubleshoot/)**
- **[PostgreSQL Troubleshooting](https://www.postgresql.org/docs/current/monitoring.html)**
- **[Cloudflare Debugging](https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/troubleshoot/)**

### 🛠️ **Useful Tools**

- **kubectl-debug**: Advanced debugging for Kubernetes
- **stern**: Multi-pod log tailing
- **k9s**: Terminal UI for Kubernetes
- **lens**: Kubernetes IDE
- **octant**: Web-based Kubernetes dashboard

---

*© 2025 TC Enterprise DevOps Platform™ - Comprehensive Troubleshooting Guide*
