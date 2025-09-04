# 🛠️ Chapter 11: Troubleshooting Guide

## 🎯 Learning Objectives
By the end of this chapter, you'll understand:
- How to diagnose and resolve common TCA InfraForge issues
- Systematic troubleshooting approaches for different components
- Tools and commands for effective problem resolution
- Prevention strategies and best practices

**⏱️ Time to Complete:** 25-30 minutes  
**💡 Difficulty:** Intermediate  
**🎯 Prerequisites:** Basic understanding of Kubernetes and container concepts

---

## 🌟 Troubleshooting Fundamentals

TCA InfraForge includes comprehensive **diagnostic tools** and **intelligent error handling** to help you quickly identify and resolve issues. This guide provides systematic approaches to common problems with clear, actionable solutions.

### Why Effective Troubleshooting Matters?
- **⚡ Fast Resolution**: Minimize downtime and service disruption
- **📊 Root Cause Analysis**: Understand underlying issues, not just symptoms
- **🛡️ Prevention**: Learn patterns to avoid future problems
- **📈 Confidence**: Build trust in your platform operations

**Real-world analogy:** Troubleshooting is like being a detective - you gather clues, follow leads, and solve the mystery to restore order!

---

## 🔍 Diagnostic Tools

### Platform Health Check

#### Quick Health Assessment
```bash
# Run comprehensive health check
./scripts/system-health-report.sh

# Check all services status
kubectl get pods -A

# Verify ingress connectivity
curl -I https://your-domain.com/health

# Check database connectivity
kubectl exec -it postgres-pod -- psql -U postgres -d tca_db -c "SELECT 1;"

# Verify Redis connectivity
kubectl exec -it redis-pod -- redis-cli ping
```

#### Automated Diagnostics
```bash
# TCA InfraForge diagnostic script
#!/bin/bash
echo "🔍 TCA InfraForge Diagnostic Report"
echo "=================================="
echo "Timestamp: $(date)"
echo ""

echo "📊 System Resources:"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.2f%%", $3/$2 * 100.0}')"
echo "Disk Usage: $(df / | tail -1 | awk '{print $5}')"
echo ""

echo "🐳 Docker Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "☸️ Kubernetes Status:"
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running
echo ""

echo "🌐 Network Connectivity:"
kubectl get svc -A
kubectl get ingress -A
echo ""

echo "📈 Service Health:"
# Check each service health endpoint
services=("api" "frontend" "postgres" "redis")
for service in "${services[@]}"; do
    if kubectl get pods -l app=tca-$service -o jsonpath='{.items[*].status.phase}' | grep -q "Running"; then
        echo "✅ $service: Healthy"
    else
        echo "❌ $service: Unhealthy"
    fi
done
```

### Log Analysis Tools

#### Centralized Logging
```bash
# View application logs
kubectl logs -f deployment/tca-api --tail=100

# View logs from specific container
kubectl logs -f deployment/tca-frontend -c frontend --tail=50

# Search logs for errors
kubectl logs deployment/tca-api | grep -i error

# View logs with timestamps
kubectl logs deployment/tca-api --timestamps

# Export logs for analysis
kubectl logs deployment/tca-api > api-logs-$(date +%Y%m%d-%H%M%S).log
```

#### Structured Log Analysis
```bash
# Parse JSON logs for errors
kubectl logs deployment/tca-api -f | jq 'select(.level == "ERROR")'

# Count error types
kubectl logs deployment/tca-api --since=1h | grep ERROR | sed 's/.*ERROR//' | sort | uniq -c | sort -nr

# Monitor error rate
kubectl logs deployment/tca-api -f | grep --line-buffered ERROR | \
while read line; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') $line"
done
```

---

## 🚨 Common Issues & Solutions

### 🔴 Critical Issues

#### Platform Won't Start
**Symptoms:**
- Services fail to deploy
- Pods stuck in Pending/CrashLoopBackOff
- Database connection failures

**Diagnostic Steps:**
```bash
# Check pod status
kubectl get pods -A

# Describe problematic pod
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# Verify resources
kubectl get nodes --field-selector=spec.unschedulable=false
```

**Solutions:**
```bash
# 1. Check resource availability
kubectl describe nodes | grep -A 10 "Allocated resources"

# 2. Verify image availability
kubectl describe pod <pod-name> | grep -A 5 "Containers"

# 3. Check network policies
kubectl get networkpolicies

# 4. Restart problematic deployment
kubectl rollout restart deployment/tca-api

# 5. Scale down and up
kubectl scale deployment tca-api --replicas=0
kubectl scale deployment tca-api --replicas=3
```

#### Database Connection Issues
**Symptoms:**
- API returns 500 errors
- "Connection refused" messages
- Slow response times

**Diagnostic Steps:**
```bash
# Check database pod status
kubectl get pods -l app=postgres

# Verify database connectivity
kubectl exec -it postgres-pod -- psql -U postgres -d tca_db -c "SELECT version();"

# Check connection pool
kubectl exec -it api-pod -- netstat -an | grep 5432

# View database logs
kubectl logs postgres-pod --tail=100
```

**Solutions:**
```bash
# 1. Restart database
kubectl rollout restart deployment/tca-postgres

# 2. Check database configuration
kubectl get configmap tca-db-config -o yaml

# 3. Verify secrets
kubectl get secret tca-db-secret -o yaml

# 4. Reset connection pool
kubectl exec -it api-pod -- pkill -f "uvicorn|gunicorn"

# 5. Check network connectivity
kubectl run test-pod --image=busybox --rm -it -- telnet postgres-service 5432
```

### 🟡 Warning Issues

#### High Resource Usage
**Symptoms:**
- CPU/Memory usage > 80%
- Slow response times
- Pod evictions

**Diagnostic Steps:**
```bash
# Monitor resource usage
kubectl top pods
kubectl top nodes

# Check resource limits
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].resources}'

# View metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

**Solutions:**
```bash
# 1. Adjust resource limits
kubectl patch deployment tca-api --type='json' -p='[{
  "op": "replace",
  "path": "/spec/template/spec/containers/0/resources/limits/memory",
  "value": "1Gi"
}]'

# 2. Scale horizontally
kubectl scale deployment tca-api --replicas=5

# 3. Optimize application
# - Add database indexes
# - Implement caching
# - Optimize queries

# 4. Check for memory leaks
kubectl exec -it api-pod -- ps aux | sort -nk +4 | tail
```

#### Slow API Responses
**Symptoms:**
- Response times > 2 seconds
- Timeout errors
- User complaints about performance

**Diagnostic Steps:**
```bash
# Check API response times
curl -w "@curl-format.txt" -o /dev/null -s http://api-service/health

# Monitor database query performance
kubectl exec -it postgres-pod -- psql -U postgres -d tca_db -c "SELECT * FROM pg_stat_activity;"

# Check cache hit rates
kubectl exec -it redis-pod -- redis-cli info stats | grep keyspace

# Profile application
kubectl exec -it api-pod -- python -m cProfile -s time app/main.py
```

**Solutions:**
```bash
# 1. Add database indexes
kubectl exec -it postgres-pod -- psql -U postgres -d tca_db -c "
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY idx_projects_created_at ON projects(created_at DESC);
"

# 2. Implement caching
# Add Redis caching layer for frequently accessed data

# 3. Optimize queries
# Use EXPLAIN ANALYZE to identify slow queries

# 4. Add connection pooling
# Configure proper connection pool settings

# 5. Implement rate limiting
kubectl apply -f rate-limit-config.yaml
```

### 🟢 Minor Issues

#### SSL/TLS Certificate Issues
**Symptoms:**
- Browser warnings about certificates
- HTTPS connection failures
- Certificate expiry warnings

**Diagnostic Steps:**
```bash
# Check certificate status
kubectl get certificate -A

# Verify certificate details
kubectl describe certificate tca-tls-cert

# Check cert-manager status
kubectl get pods -n cert-manager

# Test SSL connection
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

**Solutions:**
```bash
# 1. Renew certificate
kubectl delete certificate tca-tls-cert
kubectl apply -f certificate.yaml

# 2. Check cert-manager configuration
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod

# 3. Verify DNS configuration
nslookup your-domain.com

# 4. Update certificate secret
kubectl create secret tls tca-tls-secret --cert=cert.pem --key=key.pem
```

#### External Access Issues
**Symptoms:**
- Cannot access application externally
- DNS resolution failures
- Cloudflare tunnel issues

**Diagnostic Steps:**
```bash
# Check ingress status
kubectl get ingress
kubectl describe ingress tca-ingress

# Verify DNS resolution
nslookup your-domain.com

# Check Cloudflare tunnel
cloudflared tunnel list

# Test local connectivity
curl -H "Host: your-domain.com" http://localhost/
```

**Solutions:**
```bash
# 1. Check ingress configuration
kubectl get ingress tca-ingress -o yaml

# 2. Verify DNS records
# Update DNS records to point to correct IP

# 3. Restart ingress controller
kubectl rollout restart deployment nginx-ingress-controller -n ingress-nginx

# 4. Check Cloudflare configuration
cloudflared tunnel route dns <tunnel-name> your-domain.com

# 5. Verify firewall rules
# Ensure ports 80/443 are open
```

---

## 🛠️ Component-Specific Troubleshooting

### Container Issues

#### Image Pull Failures
```bash
# Check image status
kubectl describe pod <pod-name> | grep -A 10 "Containers"

# Verify registry access
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_TOKEN

# Check image exists
docker pull tca-infraforge/api:latest

# Update deployment with image pull policy
kubectl patch deployment tca-api --type='json' -p='[{
  "op": "replace",
  "path": "/spec/template/spec/containers/0/imagePullPolicy",
  "value": "Always"
}]'
```

#### Container Crashes
```bash
# Check container logs
kubectl logs <pod-name> --previous

# Describe pod for crash details
kubectl describe pod <pod-name>

# Check resource limits
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].resources}'

# Debug with ephemeral container
kubectl debug <pod-name> --image=busybox --target=<container-name>
```

### Kubernetes Issues

#### Pod Scheduling Problems
```bash
# Check pod status
kubectl get pods --field-selector=status.phase=Pending

# Check node resources
kubectl describe nodes | grep -A 10 "Allocated resources"

# Check pod resource requirements
kubectl describe pod <pod-name> | grep -A 10 "Requests"

# Check taints and tolerations
kubectl get nodes -o jsonpath='{.items[*].spec.taints}'

# Force reschedule
kubectl delete pod <pod-name>
```

#### Service Discovery Issues
```bash
# Check service endpoints
kubectl get endpoints <service-name>

# Verify service configuration
kubectl describe service <service-name>

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- nslookup <service-name>

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Network Issues

#### Connectivity Problems
```bash
# Test pod-to-pod connectivity
kubectl run test-pod --image=busybox --rm -it -- ping <target-pod-ip>

# Check network policies
kubectl get networkpolicies

# Verify service mesh configuration
kubectl get virtualservices
kubectl get destinationrules

# Test external connectivity
kubectl run test-pod --image=busybox --rm -it -- wget -qO- https://httpbin.org/ip
```

#### Load Balancer Issues
```bash
# Check load balancer status
kubectl get svc -l app=nginx-ingress

# Verify ingress configuration
kubectl describe ingress <ingress-name>

# Check load balancer logs
kubectl logs -n ingress-nginx deployment/nginx-ingress-controller

# Test load balancing
for i in {1..10}; do curl -s http://load-balancer-ip/ | grep "pod:"; done
```

---

## 📊 Monitoring & Alerting

### Prometheus Alerts

#### Common Alert Rules
```yaml
# prometheus-rules.yaml
groups:
  - name: tca-infraforge
    rules:
      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total{pod=~"tca-.*"}[5m]) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is {{ $value }}% for pod {{ $labels.pod }}"

      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes{pod=~"tca-.*"} / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is {{ $value }}% for pod {{ $labels.pod }}"

      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total{pod=~"tca-.*"}[5m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod crash looping"
          description: "Pod {{ $labels.pod }} is crash looping"

      - alert: ServiceDown
        expr: up{job="tca-infraforge"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Service is down"
          description: "Service {{ $labels.job }} is not responding"
```

### Grafana Dashboards

#### System Health Dashboard
```json
{
  "dashboard": {
    "title": "TCA InfraForge System Health",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(container_cpu_usage_seconds_total{pod=~\"tca-.*\"}[5m])",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "container_memory_usage_bytes{pod=~\"tca-.*\"} / container_spec_memory_limit_bytes",
            "legendFormat": "{{pod}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"tca-api\"}[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      }
    ]
  }
}
```

### Alert Manager Configuration
```yaml
# alertmanager.yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@tca-infraforge.com'
  smtp_auth_username: 'alerts@tca-infraforge.com'
  smtp_auth_password: 'your-app-password'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'

receivers:
  - name: 'email'
    email_configs:
      - to: 'admin@tca-infraforge.com'
        subject: 'TCA InfraForge Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          {{ end }}
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'your-pagerduty-service-key'
```

---

## 🔧 Advanced Troubleshooting

### Performance Profiling

#### Application Profiling
```bash
# Python profiling
kubectl exec -it api-pod -- python -m cProfile -o profile.prof app/main.py
kubectl cp api-pod:profile.prof profile.prof
python -m pstats profile.prof

# Memory profiling
kubectl exec -it api-pod -- python -c "
import tracemalloc
tracemalloc.start()
# Your code here
snapshot = tracemalloc.take_snapshot()
for stat in snapshot.statistics('lineno')[:10]:
    print(stat)
"

# Database query profiling
kubectl exec -it postgres-pod -- psql -U postgres -d tca_db -c "
EXPLAIN ANALYZE SELECT * FROM users WHERE created_at > '2024-01-01';
"
```

#### Network Debugging
```bash
# Packet capture
kubectl run netshoot --image=nicolaka/netshoot --rm -it -- /bin/bash
tcpdump -i eth0 -w capture.pcap

# Network connectivity testing
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
telnet service-name 8080
curl -v http://service-name:8080/health

# DNS debugging
nslookup service-name.default.svc.cluster.local
dig @kube-dns.kube-system.svc.cluster.local service-name.default.svc.cluster.local
```

### Log Correlation

#### Distributed Tracing Setup
```yaml
# jaeger-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: monitoring
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
        env:
        - name: COLLECTOR_OTLP_ENABLED
          value: "true"
```

#### Log Correlation Queries
```bash
# Correlate logs by request ID
kubectl logs deployment/tca-api | grep "request-id: 12345"

# Find related logs across services
for service in api frontend backend; do
  echo "=== $service logs ==="
  kubectl logs deployment/tca-$service --since=1h | grep "correlation-id"
done

# Search for error patterns
kubectl logs -l app=tca-api --all-containers --since=24h | \
jq -r 'select(.level == "ERROR") | "\(.timestamp) \(.message) \(.request_id // "no-request-id")"'
```

---

## 📋 Prevention Strategies

### Proactive Monitoring

#### Health Check Endpoints
```python
# health.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
import redis
import psycopg2
from app.database import get_db
from app.config import settings

router = APIRouter()

@router.get("/health/live")
async def liveness_check():
    """Kubernetes liveness probe."""
    return {"status": "alive"}

@router.get("/health/ready")
async def readiness_check(db: Session = Depends(get_db)):
    """Kubernetes readiness probe."""
    try:
        # Check database connectivity
        db.execute("SELECT 1")
        return {"status": "ready", "database": "connected"}
    except Exception as e:
        return {"status": "not ready", "database": str(e)}, 503

@router.get("/health/deep")
async def deep_health_check(db: Session = Depends(get_db)):
    """Comprehensive health check."""
    health_status = {
        "status": "healthy",
        "checks": {}
    }

    # Database check
    try:
        result = db.execute("SELECT COUNT(*) FROM users").scalar()
        health_status["checks"]["database"] = {
            "status": "healthy",
            "user_count": result
        }
    except Exception as e:
        health_status["checks"]["database"] = {
            "status": "unhealthy",
            "error": str(e)
        }
        health_status["status"] = "unhealthy"

    # Redis check
    try:
        redis_client = redis.from_url(settings.REDIS_URL)
        redis_client.ping()
        health_status["checks"]["redis"] = {"status": "healthy"}
    except Exception as e:
        health_status["checks"]["redis"] = {
            "status": "unhealthy",
            "error": str(e)
        }
        health_status["status"] = "unhealthy"

    # External service check
    try:
        # Check external API dependency
        health_status["checks"]["external_api"] = {"status": "healthy"}
    except Exception as e:
        health_status["checks"]["external_api"] = {
            "status": "unhealthy",
            "error": str(e)
        }

    return health_status
```

### Automated Recovery

#### Self-Healing Configurations
```yaml
# pod-disruption-budget.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: tca-api-pdb
  namespace: tca-infraforge
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: tca-api

# horizontal-pod-autoscaler.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: tca-api-hpa
  namespace: tca-infraforge
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: tca-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

### Backup and Recovery

#### Automated Backups
```bash
# backup-script.sh
#!/bin/bash
BACKUP_DIR="/opt/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Database backup
kubectl exec postgres-pod -- pg_dump -U postgres tca_db > $BACKUP_DIR/db_$TIMESTAMP.sql

# Configuration backup
kubectl get configmaps -o yaml > $BACKUP_DIR/configmaps_$TIMESTAMP.yaml
kubectl get secrets -o yaml > $BACKUP_DIR/secrets_$TIMESTAMP.yaml

# Persistent volume backup
kubectl cp postgres-pod:/var/lib/postgresql/data $BACKUP_DIR/pv_$TIMESTAMP

# Upload to cloud storage
aws s3 cp $BACKUP_DIR/db_$TIMESTAMP.sql s3://tca-backups/database/
aws s3 cp $BACKUP_DIR/configmaps_$TIMESTAMP.yaml s3://tca-backups/config/

# Cleanup old backups
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.yaml" -mtime +7 -delete
```

---

## 📚 Summary

TCA InfraForge's troubleshooting capabilities provide **comprehensive diagnostic tools** and **systematic problem resolution** approaches:

- **🔍 Diagnostic Tools**: Health checks, log analysis, and monitoring
- **🚨 Issue Resolution**: Step-by-step solutions for common problems
- **🛠️ Component-Specific**: Targeted troubleshooting for each platform component
- **📊 Proactive Monitoring**: Alerts, dashboards, and automated recovery
- **🔧 Advanced Techniques**: Profiling, tracing, and performance optimization

### Key Takeaways
1. **Systematic Approach**: Follow structured diagnostic processes
2. **Log Analysis**: Use logs as primary source of diagnostic information
3. **Monitoring First**: Implement comprehensive monitoring before issues occur
4. **Automation**: Use automated recovery and self-healing capabilities
5. **Prevention**: Learn from issues to prevent future occurrences

### Troubleshooting Checklist
- [ ] Check system resources (CPU, memory, disk)
- [ ] Review recent logs for error messages
- [ ] Verify service connectivity and DNS resolution
- [ ] Check configuration files and secrets
- [ ] Test individual components in isolation
- [ ] Monitor network traffic and firewall rules
- [ ] Validate backup and recovery procedures
- [ ] Document findings and solutions

---

## 🎯 What's Next?

Now that you understand troubleshooting, you're ready to:

1. **[⚙️ Advanced Configuration](./11-performance-optimization.md)** - Optimize performance and scaling
2. **[📈 CI/CD Pipeline](./12-ci-cd-pipeline.md)** - Set up automated deployment
3. **[🤝 Contributing](./13-contributing-development.md)** - Contribute to the platform

**💡 Pro Tip:** The best troubleshooting is preventive - implement comprehensive monitoring and automated recovery to catch issues before they impact users!

---

*Thank you for learning about TCA InfraForge's troubleshooting capabilities! With these tools and techniques, you'll be able to maintain a highly reliable enterprise platform.* 🚀
