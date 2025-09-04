# 🌐 Chapter 6: Networking & Ingress

## 🎯 Learning Objectives
By the end of this chapter, you'll understand:
- How to configure NGINX Ingress Controller for external access
- Service mesh patterns with Istio integration
- Load balancing strategies and traffic management
- Network security policies and service discovery

**⏱️ Time to Complete:** 20-25 minutes  
**💡 Difficulty:** Intermediate  
**🎯 Prerequisites:** Understanding of Kubernetes networking basics

---

## 🌟 Networking Fundamentals

TCA InfraForge implements a **comprehensive networking architecture** that ensures secure, scalable, and reliable communication between services. This chapter covers the networking patterns that enable enterprise-grade connectivity.

### Why Advanced Networking Matters?
- **🔒 Security**: Network segmentation and zero-trust architecture
- **⚡ Performance**: Optimized load balancing and traffic routing
- **📊 Observability**: Complete visibility into network traffic
- **🔄 Reliability**: Automatic failover and traffic management
- **📈 Scalability**: Handle thousands of concurrent connections

**Real-world analogy:** Think of networking as the nervous system of your application - it connects everything, routes signals efficiently, and protects against threats!

---

## 🚪 NGINX Ingress Controller

### Installation and Configuration

#### Install NGINX Ingress Controller
```bash
# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set defaultBackend.enabled=true

# Verify installation
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

#### Custom NGINX Configuration
```yaml
# nginx-ingress-values.yaml
controller:
  replicaCount: 2
  config:
    use-forwarded-headers: "true"
    proxy-real-ip-cidr: "0.0.0.0/0"
    proxy-body-size: "100m"
    proxy-read-timeout: "300"
    proxy-send-timeout: "300"
    server-tokens: "false"
    ssl-redirect: "false"
    force-ssl-redirect: "false"
    use-gzip: "true"
    gzip-types: "text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript"
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
  podSecurityContext:
    runAsUser: 101
    runAsNonRoot: true
    fsGroup: 101
```

#### TLS/SSL Configuration
```yaml
# tls-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: tca-tls-secret
  namespace: tca-infraforge
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi... # Base64 encoded certificate
  tls.key: LS0tLS1CRUdJTi... # Base64 encoded private key

# Let's Encrypt ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@tca-infraforge.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Ingress Resource Configuration

#### Basic Ingress
```yaml
# basic-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tca-basic-ingress
  namespace: tca-infraforge
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - api.tca-infraforge.com
    - app.tca-infraforge.com
    secretName: tca-tls-secret
  rules:
  - host: api.tca-infraforge.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tca-api-service
            port:
              number: 8000
  - host: app.tca-infraforge.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tca-frontend-service
            port:
              number: 3000
```

#### Advanced Ingress with Routing
```yaml
# advanced-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tca-advanced-ingress
  namespace: tca-infraforge
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://app.tca-infraforge.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization"
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
spec:
  tls:
  - hosts:
    - api.tca-infraforge.com
    secretName: tca-tls-secret
  rules:
  - host: api.tca-infraforge.com
    http:
      paths:
      - path: /api/v1(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: tca-api-service
            port:
              number: 8000
      - path: /health
        pathType: Exact
        backend:
          service:
            name: tca-health-service
            port:
              number: 8080
      - path: /metrics
        pathType: Exact
        backend:
          service:
            name: tca-metrics-service
            port:
              number: 9090
```

#### Canary Deployments with Ingress
```yaml
# canary-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tca-canary-ingress
  namespace: tca-infraforge
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "20"
    nginx.ingress.kubernetes.io/canary-by-header: "canary"
    nginx.ingress.kubernetes.io/canary-by-header-value: "always"
spec:
  rules:
  - host: api.tca-infraforge.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tca-api-canary-service
            port:
              number: 8000
```

---

## 🕸️ Service Mesh with Istio

### Istio Installation

#### Install Istio
```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*

# Add to PATH
export PATH=$PWD/bin:$PATH

# Install Istio with demo profile
istioctl install --set profile=demo -y

# Verify installation
kubectl get pods -n istio-system
```

#### Enable Istio Injection
```bash
# Label namespace for automatic injection
kubectl label namespace tca-infraforge istio-injection=enabled

# Or enable for specific deployment
kubectl patch deployment tca-api --type='json' -p='[{
  "op": "add",
  "path": "/spec/template/metadata/labels",
  "value": {"istio.io/rev": "default"}
}]'
```

### Traffic Management

#### Virtual Services
```yaml
# virtual-service.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: tca-api-virtual-service
  namespace: tca-infraforge
spec:
  hosts:
  - api.tca-infraforge.com
  gateways:
  - tca-gateway
  http:
  - match:
    - uri:
        prefix: "/api/v1"
    route:
    - destination:
        host: tca-api-service
        subset: v1
      weight: 80
    - destination:
        host: tca-api-service
        subset: v2
      weight: 20
  - match:
    - uri:
        prefix: "/health"
    route:
    - destination:
        host: tca-health-service
  - match:
    - headers:
        user-agent:
          regex: ".*curl.*"
    route:
    - destination:
        host: tca-api-service
        subset: debug
```

#### Destination Rules
```yaml
# destination-rule.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: tca-api-destination-rule
  namespace: tca-infraforge
spec:
  host: tca-api-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: debug
    labels:
      version: debug
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 10
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 30s
```

#### Gateway Configuration
```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: tca-gateway
  namespace: tca-infraforge
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: tca-tls-secret
    hosts:
    - api.tca-infraforge.com
    - app.tca-infraforge.com
```

### Security Policies

#### Peer Authentication
```yaml
# peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: tca-peer-authentication
  namespace: tca-infraforge
spec:
  selector:
    matchLabels:
      app: tca-api
  mtls:
    mode: STRICT
```

#### Authorization Policies
```yaml
# authorization-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: tca-api-authorization
  namespace: tca-infraforge
spec:
  selector:
    matchLabels:
      app: tca-api
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/tca-infraforge/sa/tca-frontend"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/v1/*"]
  - from:
    - source:
        namespaces: ["istio-system"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/health"]
```

---

## ⚖️ Load Balancing Strategies

### Kubernetes Service Types

#### ClusterIP Service
```yaml
# clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: tca-api-clusterip
  namespace: tca-infraforge
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
  selector:
    app: tca-api
```

#### LoadBalancer Service
```yaml
# loadbalancer-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: tca-api-loadbalancer
  namespace: tca-infraforge
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:region:account:certificate/certificate-id"
spec:
  type: LoadBalancer
  ports:
  - port: 443
    targetPort: 8000
    protocol: TCP
  selector:
    app: tca-api
```

#### NodePort Service
```yaml
# nodeport-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: tca-api-nodeport
  namespace: tca-infraforge
spec:
  type: NodePort
  ports:
  - port: 8000
    targetPort: 8000
    nodePort: 30000
    protocol: TCP
  selector:
    app: tca-api
```

### Advanced Load Balancing

#### Session Affinity
```yaml
# session-affinity-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: tca-api-sticky
  namespace: tca-infraforge
spec:
  type: ClusterIP
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
  ports:
  - port: 8000
    targetPort: 8000
  selector:
    app: tca-api
```

#### External Load Balancer
```yaml
# external-lb-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: tca-external-lb
  namespace: tca-infraforge
  annotations:
    metallb.universe.tf/address-pool: production-public-ips
    metallb.universe.tf/allow-shared-ip: tca-shared-ip
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.100
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
  selector:
    app: tca-nginx
```

---

## 🔒 Network Security

### Network Policies

#### Basic Network Policy
```yaml
# basic-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tca-api-network-policy
  namespace: tca-infraforge
spec:
  podSelector:
    matchLabels:
      app: tca-api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: tca-frontend
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

#### Advanced Security Policies
```yaml
# advanced-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tca-zero-trust-policy
  namespace: tca-infraforge
spec:
  podSelector:
    matchLabels:
      app: tca-api
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
          app: tca-gateway
    - namespaceSelector:
        matchLabels:
          name: monitoring
      podSelector:
        matchLabels:
          component: prometheus
    ports:
    - protocol: TCP
      port: 8000
    - protocol: TCP
      port: 8443
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
  - to:
    - podSelector:
        matchLabels:
          app: tca-vault
    ports:
    - protocol: TCP
      port: 8200
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 443
```

### Service Mesh Security

#### Mutual TLS
```yaml
# mtls-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: tca-mtls-policy
  namespace: tca-infraforge
spec:
  selector:
    matchLabels:
      app: tca-api
  mtls:
    mode: STRICT
```

#### JWT Authentication
```yaml
# jwt-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: tca-jwt-policy
  namespace: tca-infraforge
spec:
  selector:
    matchLabels:
      app: tca-api
  jwtRules:
  - issuer: "https://auth.tca-infraforge.com"
    jwksUri: "https://auth.tca-infraforge.com/.well-known/jwks.json"
    forwardOriginalToken: true
```

---

## 🔍 Service Discovery

### Kubernetes DNS

#### DNS Configuration
```yaml
# coredns-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
            max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
    tca-infraforge.local:53 {
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            upstream
            fallthrough in-addr.arpa ip6.arpa
        }
    }
```

#### Service Discovery Patterns
```yaml
# service-discovery-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tca-service-discovery
  namespace: tca-infraforge
data:
  services.json: |
    {
      "api": {
        "host": "tca-api-service.tca-infraforge.svc.cluster.local",
        "port": 8000,
        "protocol": "http",
        "health": "/health"
      },
      "database": {
        "host": "tca-postgres-service.tca-infraforge.svc.cluster.local",
        "port": 5432,
        "protocol": "postgresql"
      },
      "cache": {
        "host": "tca-redis-service.tca-infraforge.svc.cluster.local",
        "port": 6379,
        "protocol": "redis"
      }
    }
```

### External Service Discovery

#### External Name Service
```yaml
# external-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: tca-external-api
  namespace: tca-infraforge
spec:
  type: ExternalName
  externalName: api.external-service.com
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
```

#### Headless Service
```yaml
# headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: tca-api-headless
  namespace: tca-infraforge
spec:
  clusterIP: None
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
  selector:
    app: tca-api
```

---

## 📊 Monitoring Network Traffic

### Network Monitoring

#### Prometheus ServiceMonitor
```yaml
# network-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tca-network-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: nginx-ingress
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
  namespaceSelector:
    matchNames:
    - ingress-nginx
```

#### Network Policies Monitoring
```yaml
# network-policy-monitor.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tca-network-alerts
  namespace: monitoring
data:
  alerts.yml: |
    groups:
    - name: network
      rules:
      - alert: NetworkPolicyViolation
        expr: rate(kube_network_policy_rule_evaluation_total{outcome="deny"}[5m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Network policy violation detected"
          description: "Network traffic was denied by policy {{ $labels.policy }}"
      - alert: ServiceUnavailable
        expr: up{job="kubernetes-service-endpoints"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Service unavailable"
          description: "Service {{ $labels.service }} has no healthy endpoints"
```

### Traffic Analysis

#### Istio Telemetry
```yaml
# telemetry-config.yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: tca-telemetry
  namespace: tca-infraforge
spec:
  selector:
    matchLabels:
      app: tca-api
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: REQUEST_COUNT
        mode: CLIENT_AND_SERVER
      tagOverrides:
        request_method:
          value: "request.method | \"unknown\""
    - match:
        metric: REQUEST_DURATION
        mode: CLIENT_AND_SERVER
      tagOverrides:
        response_code:
          value: "response.code | 0"
  accessLogging:
  - providers:
    - name: envoy
    disabled: false
```

---

## 🔧 Troubleshooting Network Issues

### Common Network Problems

#### DNS Resolution Issues
```bash
# Check DNS resolution
kubectl run test-pod --image=busybox --rm -it -- nslookup tca-api-service

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# View DNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS configuration
kubectl run dns-test --image=busybox --rm -it -- cat /etc/resolv.conf
```

#### Service Connectivity Issues
```bash
# Check service endpoints
kubectl get endpoints tca-api-service

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it -- wget -qO- tca-api-service:8000/health

# Check service configuration
kubectl describe service tca-api-service

# Verify pod labels match service selector
kubectl get pods --show-labels | grep tca-api
```

#### Ingress Issues
```bash
# Check ingress status
kubectl get ingress tca-ingress

# Describe ingress for details
kubectl describe ingress tca-ingress

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/nginx-ingress-controller

# Test ingress connectivity
curl -H "Host: api.tca-infraforge.com" http://localhost/
```

#### Network Policy Issues
```bash
# Check network policies
kubectl get networkpolicies

# Describe specific policy
kubectl describe networkpolicy tca-api-network-policy

# Test connectivity with network utils
kubectl run test-pod --image=busybox --rm -it -- telnet tca-api-service 8000
```

---

## 📋 Best Practices

### Ingress Best Practices
- **🔒 TLS everywhere**: Always use HTTPS with valid certificates
- **📊 Rate limiting**: Implement rate limiting to prevent abuse
- **🔍 Logging**: Enable comprehensive access logging
- **⚡ Caching**: Use caching to improve performance
- **🔄 Health checks**: Configure proper health checks
- **🏷️ Annotations**: Use annotations for advanced configuration

### Service Mesh Best Practices
- **🔒 mTLS**: Enable mutual TLS for all service communication
- **📊 Observability**: Implement distributed tracing and metrics
- **⚖️ Load balancing**: Use intelligent load balancing algorithms
- **🔄 Circuit breaking**: Implement circuit breakers for resilience
- **📈 Scaling**: Auto-scale based on traffic patterns

### Security Best Practices
- **🚫 Default deny**: Use default-deny network policies
- **🔐 Encryption**: Encrypt all network traffic
- **👥 Least privilege**: Grant minimal required network access
- **📊 Monitoring**: Monitor all network traffic and anomalies
- **🔄 Regular audits**: Regularly audit network policies and configurations

---

## 📚 Summary

TCA InfraForge's networking architecture provides enterprise-grade connectivity with:

- **🚪 NGINX Ingress**: Advanced ingress controller with TLS and load balancing
- **🕸️ Istio Service Mesh**: Comprehensive service mesh with traffic management
- **⚖️ Load Balancing**: Multiple load balancing strategies for optimal performance
- **🔒 Security**: Network policies and mutual TLS for zero-trust security
- **🔍 Monitoring**: Complete visibility into network traffic and performance

### Key Takeaways
1. **Ingress Control**: NGINX provides powerful routing and security features
2. **Service Mesh**: Istio enables advanced traffic management and observability
3. **Load Balancing**: Choose the right strategy for your application needs
4. **Security First**: Implement network policies and encryption
5. **Monitor Everything**: Network monitoring is crucial for reliability

---

## 🎯 What's Next?

Now that you understand networking fundamentals, you're ready to:

1. **[📊 Monitoring & Observability](./07-monitoring-observability.md)** - Set up comprehensive monitoring
2. **[🚀 Enterprise Applications](./08-enterprise-applications.md)** - Deploy your applications
3. **[🔒 Security & Compliance](./09-security-compliance.md)** - Implement security measures

**💡 Pro Tip:** Start with basic ingress and gradually add service mesh features as your application grows. Always implement network policies from the beginning for better security!

---

*Thank you for learning about TCA InfraForge's networking capabilities! Proper networking is the foundation of scalable, secure enterprise applications.* 🚀
