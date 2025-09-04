# 🔒 Chapter 9: Security & Compliance

## 🎯 Learning Objectives
By the end of this chapter, you'll understand:
- TCA InfraForge's security-first architecture
- Implementing zero-trust security principles
- Compliance frameworks and audit capabilities
- Security hardening and best practices

**⏱️ Time to Complete:** 30-35 minutes  
**💡 Difficulty:** Intermediate to Advanced  
**🎯 Prerequisites:** Understanding of networking and system administration

---

## 🛡️ Security-First Philosophy

TCA InfraForge is built with **security as the foundation**, not an afterthought. We implement **defense in depth** - multiple layers of protection that work together to create an impenetrable security posture.

### Zero-Trust Architecture Principles
- **🔐 Never Trust, Always Verify:** Every request is authenticated and authorized
- **🛡️ Least Privilege Access:** Users get only the minimum permissions needed
- **📊 Complete Visibility:** Full audit trail of all activities
- **🔄 Micro-Segmentation:** Network isolation between all components
- **🚨 Continuous Monitoring:** Real-time threat detection and response

**Real-world analogy:** Like a bank vault with multiple combination locks, security cameras, motion sensors, and armed guards - each layer provides protection even if others fail.

---

## 🏗️ Security Architecture Overview

### Defense in Depth Layers
```mermaid
graph TB
    subgraph "Network Security"
        CLOUDFLARE[☁️ Cloudflare WAF<br/>DDoS Protection<br/>Rate Limiting]
        INGRESS[🌐 NGINX Ingress<br/>SSL Termination<br/>Request Filtering]
        NETWORK_POLICIES[🔒 Kubernetes Network Policies<br/>Traffic Segmentation]
        SERVICE_MESH[🔗 Service Mesh<br/>mTLS Encryption]
    end

    subgraph "Access Control"
        OAUTH[🔐 OAuth2 Proxy<br/>Authentication Gateway]
        RBAC[👥 Role-Based Access Control<br/>Authorization]
        VAULT[🔒 HashiCorp Vault<br/>Secrets Management]
        CERT_MANAGER[📜 Certificate Manager<br/>SSL/TLS Certificates]
    end

    subgraph "Data Protection"
        ENCRYPTION[🔐 Data Encryption<br/>At Rest & In Transit]
        BACKUP_ENCRYPTION[💾 Encrypted Backups<br/>Secure Storage]
        AUDIT_LOGGING[📊 Audit Logging<br/>Compliance Tracking]
        DATA_MASKING[🎭 Data Masking<br/>PII Protection]
    end

    subgraph "Threat Detection"
        INTRUSION_DETECTION[🚨 Intrusion Detection<br/>Anomaly Detection]
        LOG_ANALYSIS[🔍 Log Analysis<br/>Pattern Recognition]
        VULNERABILITY_SCANNING[🛡️ Vulnerability Scanning<br/>Security Updates]
        COMPLIANCE_MONITORING[📋 Compliance Monitoring<br/>Policy Enforcement]
    end

    CLOUDFLARE --> INGRESS
    INGRESS --> NETWORK_POLICIES
    NETWORK_POLICIES --> SERVICE_MESH
    OAUTH --> RBAC
    RBAC --> VAULT
    VAULT --> CERT_MANAGER
    ENCRYPTION --> BACKUP_ENCRYPTION
    BACKUP_ENCRYPTION --> AUDIT_LOGGING
    AUDIT_LOGGING --> DATA_MASKING
    INTRUSION_DETECTION --> LOG_ANALYSIS
    LOG_ANALYSIS --> VULNERABILITY_SCANNING
    VULNERABILITY_SCANNING --> COMPLIANCE_MONITORING
```

### Security Control Categories

#### Prevent (Block Attacks)
- **🛡️ Web Application Firewall (WAF):** Blocks common web attacks
- **🔒 Network Policies:** Prevents unauthorized network access
- **👥 Access Controls:** Enforces authentication and authorization
- **🔐 Encryption:** Protects data in transit and at rest

#### Detect (Identify Threats)
- **📊 Intrusion Detection:** Monitors for suspicious activities
- **🔍 Log Analysis:** Identifies patterns and anomalies
- **📈 Anomaly Detection:** Flags unusual behavior
- **🛡️ Vulnerability Scanning:** Finds security weaknesses

#### Respond (Handle Incidents)
- **🚨 Automated Alerts:** Immediate notification of security events
- **🔄 Incident Response:** Pre-defined response procedures
- **📋 Forensic Analysis:** Detailed investigation capabilities
- **🔧 Recovery Procedures:** Quick restoration of services

#### Recover (Restore Operations)
- **💾 Secure Backups:** Encrypted, tested backup procedures
- **🔄 Disaster Recovery:** Business continuity planning
- **📊 Recovery Testing:** Regular DR drills and validation
- **📈 Lessons Learned:** Continuous improvement process

---

## 🔐 Authentication & Authorization

### Multi-Factor Authentication (MFA)
TCA InfraForge supports multiple authentication methods:

#### OAuth2 Integration
```yaml
# OAuth2 Proxy Configuration
oauth2_proxy:
  provider: "github"  # or google, azure, okta, etc.
  client_id: "your_client_id"
  client_secret: "your_client_secret"
  cookie_secret: "random_string_here"
  email_domains:
    - "company.com"
  github_org: "your-organization"
```

#### LDAP/Active Directory Integration
```yaml
# LDAP Authentication Setup
ldap:
  host: "ldap.company.com"
  port: 389
  bind_dn: "cn=admin,dc=company,dc=com"
  bind_password: "admin_password"
  user_search_base: "ou=users,dc=company,dc=com"
  user_search_filter: "(uid=%s)"
  group_search_base: "ou=groups,dc=company,dc=com"
```

### Role-Based Access Control (RBAC)

#### Pre-defined Roles
```yaml
# Kubernetes RBAC Configuration
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tca-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tca-developer
rules:
- apiGroups: ["apps", "extensions"]
  resources: ["deployments", "replicasets", "pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tca-viewer
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
```

#### Custom Role Creation
```bash
# Create custom role for specific team
kubectl create role team-alpha-developer \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=pods,services,deployments \
  --namespace=team-alpha

# Bind role to user
kubectl create rolebinding team-alpha-binding \
  --role=team-alpha-developer \
  --user=john.doe@company.com \
  --namespace=team-alpha
```

---

## 🔒 Secrets Management with HashiCorp Vault

### Vault Architecture
```mermaid
graph TB
    subgraph "Applications"
        API[🔌 API Server]
        WEB[🌐 Web Frontend]
        WORKER[⚙️ Background Worker]
    end

    subgraph "Vault Server"
        VAULT[🔒 HashiCorp Vault<br/>Secrets Engine]
        AUTH[🔐 Authentication<br/>Methods]
        POLICIES[📋 Access Policies<br/>RBAC]
        AUDIT[📊 Audit Device<br/>Logging]
    end

    subgraph "Secret Storage"
        KV[🔑 Key-Value Store<br/>Static Secrets]
        DB[💾 Database Credentials<br/>Dynamic Secrets]
        PKI[📜 PKI Certificates<br/>SSL/TLS Certs]
        TRANSIT[🔄 Transit Engine<br/>Encryption as Service]
    end

    API --> VAULT
    WEB --> VAULT
    WORKER --> VAULT
    VAULT --> KV
    VAULT --> DB
    VAULT --> PKI
    VAULT --> TRANSIT
```

### Setting Up Vault Secrets

#### 1. Initialize Vault
```bash
# Access Vault UI
kubectl port-forward svc/vault 8200:8200
open https://localhost:8200

# Initialize with key shares
vault operator init -key-shares=5 -key-threshold=3

# Unseal Vault (run 3 times with different keys)
vault operator unseal
```

#### 2. Configure Authentication
```bash
# Enable Kubernetes authentication
vault auth enable kubernetes

# Configure Kubernetes auth method
vault write auth/kubernetes/config \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create policy for database access
vault policy write db-access - <<EOF
path "database/creds/my-role" {
  capabilities = ["read"]
}
EOF
```

#### 3. Store Application Secrets
```bash
# Store static secrets
vault kv put secret/myapp/database \
  username="myapp_user" \
  password="super_secret_password" \
  host="postgres-service"

# Enable database secrets engine
vault secrets enable database

# Configure database connection
vault write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="my-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/myapp" \
  username="vault_admin" \
  password="vault_admin_password"
```

#### 4. Application Integration
```python
# Python example: Reading secrets from Vault
import hvac

# Initialize Vault client
client = hvac.Client(url='https://vault.tca-infraforge.com:8200')

# Authenticate with Kubernetes service account
with open('/var/run/secrets/kubernetes.io/serviceaccount/token') as f:
    jwt = f.read()

client.auth_kubernetes("myapp", jwt)

# Read database credentials
secrets = client.secrets.kv.v2.read_secret_version('secret/myapp/database')
db_config = {
    'username': secrets['data']['data']['username'],
    'password': secrets['data']['data']['password'],
    'host': secrets['data']['data']['host']
}
```

---

## 🛡️ Network Security

### Kubernetes Network Policies

#### Default Security Policy
```yaml
# Block all traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

---
# Allow internal traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: production
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: production
```

#### Application-Specific Policies
```yaml
# API Server network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-server-policy
spec:
  podSelector:
    matchLabels:
      app: api-server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress
    - podSelector:
        matchLabels:
          app: web-frontend
    ports:
    - protocol: TCP
      port: 8080

---
# Database isolation policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-isolation
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-server
    ports:
    - protocol: TCP
      port: 5432
```

### Service Mesh Security (Istio)

#### Mutual TLS (mTLS) Configuration
```yaml
# Enable mTLS for all services
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT

---
# Destination rule for traffic policies
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-server-mtls
spec:
  host: api-server.production.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

---

## 📜 Compliance & Audit Logging

### Compliance Frameworks Supported

#### SOC 2 Type II Compliance
- **Trust Services Criteria:** Security, Availability, Processing Integrity
- **Audit Trail:** Complete activity logging with tamper-proof storage
- **Access Controls:** Role-based access with audit logging
- **Change Management:** Version-controlled configuration changes

#### GDPR Compliance
- **Data Protection:** Encryption of personal data at rest and in transit
- **Access Controls:** Principle of least privilege
- **Audit Logging:** Complete data access and processing logs
- **Data Portability:** Export capabilities for user data

#### HIPAA Compliance
- **Data Encryption:** Protected health information (PHI) encryption
- **Access Logging:** All PHI access events logged
- **Network Security:** Secure transmission of health data
- **Disaster Recovery:** Business continuity for health data

### Audit Logging Implementation

#### Centralized Audit Collection
```yaml
# Fluent Bit audit log configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-audit-config
data:
  fluent-bit.conf: |
    [INPUT]
        Name              tail
        Path              /var/log/kubernetes/audit.log
        Parser            json
        Tag               audit.*

    [OUTPUT]
        Name              elasticsearch
        Host              elasticsearch.logging.svc.cluster.local
        Port              9200
        Index             audit-logs
        Type              audit
```

#### Audit Log Analysis
```bash
# Search for specific user activities
kubectl logs -f deployment/audit-analyzer | grep "user:john.doe"

# Analyze access patterns
kubectl exec -it audit-analyzer -- \
  python analyze_access_patterns.py --user=john.doe --timeframe=24h

# Generate compliance reports
kubectl exec -it audit-analyzer -- \
  python generate_compliance_report.py --framework=gdpr --period=monthly
```

---

## 🛡️ Vulnerability Management

### Automated Security Scanning

#### Container Image Scanning
```bash
# Scan images before deployment
trivy image --exit-code 1 --no-progress myapp:latest

# Scan running containers
trivy k8s --report summary cluster

# Generate security reports
trivy image --format json --output results.json myapp:latest
```

#### Kubernetes Cluster Scanning
```bash
# Kube-bench security assessment
kube-bench run --targets=master,node,etcd,policies

# CIS Kubernetes benchmark
kube-bench run --benchmark cis-1.6

# Generate compliance report
kube-bench run --json --output compliance-report.json
```

### Security Updates & Patching

#### Automated Updates
```yaml
# Kyverno policy for security updates
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-security-updates
spec:
  validationFailureAction: enforce
  rules:
  - name: check-image-security
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Image must be from trusted registry and have security scan"
      pattern:
        spec:
          containers:
          - image: "trusted-registry.com/*"
            securityContext:
              runAsNonRoot: true
              runAsUser: 1000
```

---

## 🚨 Incident Response

### Security Incident Response Plan

#### Phase 1: Detection & Assessment (0-15 minutes)
```bash
# 1. Confirm the incident
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20

# 2. Isolate affected systems
kubectl cordon affected-node

# 3. Gather initial evidence
kubectl logs --previous affected-pod > incident-evidence.log

# 4. Notify security team
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Security incident detected"}' \
  SLACK_WEBHOOK_URL
```

#### Phase 2: Containment (15-60 minutes)
```bash
# 1. Block malicious traffic
kubectl apply -f emergency-network-policy.yaml

# 2. Revoke compromised credentials
vault token revoke compromised_token

# 3. Update security policies
kubectl apply -f updated-security-policies.yaml

# 4. Take system snapshots
kubectl get all -o yaml > incident-snapshot.yaml
```

#### Phase 3: Eradication (1-4 hours)
```bash
# 1. Remove malicious code
kubectl delete pod malicious-pod

# 2. Patch vulnerabilities
kubectl set image deployment/myapp myapp=secure-image:v2

# 3. Update secrets
vault kv put secret/myapp/api-key value=new_secure_key

# 4. Clean up backdoors
kubectl apply -f security-hardening.yaml
```

#### Phase 4: Recovery & Lessons Learned (4+ hours)
```bash
# 1. Restore from clean backups
./scripts/restore-from-backup.sh clean-backup-20241201

# 2. Validate system integrity
./scripts/security-validation.sh

# 3. Monitor for recurrence
kubectl apply -f enhanced-monitoring.yaml

# 4. Document lessons learned
# Create incident report and update procedures
```

### Automated Incident Response
```yaml
# Kyverno policy for automated response
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: automated-incident-response
spec:
  rules:
  - name: quarantine-suspicious-pod
    match:
      resources:
        kinds:
        - Pod
    preconditions:
      all:
      - key: "{{ request.object.spec.containers[].securityContext.privileged }}"
        operator: Equals
        value: true
    mutate:
      patchStrategicMerge:
        metadata:
          labels:
            security: quarantined
        spec:
          nodeSelector:
            security: quarantine
```

---

## 📊 Security Monitoring & Reporting

### Security Dashboards

#### Real-Time Security Monitoring
```bash
# Access security dashboard
open https://grafana.tca-infraforge.com/d/security-overview

# Key security metrics to monitor:
# - Failed authentication attempts
# - Unusual network traffic patterns
# - Privilege escalation events
# - Configuration changes
# - Compliance violations
```

#### Automated Security Reports
```bash
# Generate daily security report
./scripts/generate-security-report.sh --period=daily

# Generate compliance report
./scripts/generate-compliance-report.sh --framework=soc2

# Send reports to stakeholders
./scripts/send-security-reports.sh --recipients=security-team@company.com
```

### Security Metrics & KPIs

#### Key Security Indicators
- **Authentication Success Rate:** > 99.9%
- **Average Response Time to Threats:** < 15 minutes
- **False Positive Rate:** < 5%
- **Compliance Score:** > 95%
- **Security Incident Response Time:** < 1 hour
- **Patch Management Coverage:** > 98%

---

## 🆘 Security Troubleshooting

### Common Security Issues

#### Issue: Authentication Failures
```
❌ Error: Login attempts failing
✅ Solution: Check OAuth2 configuration
   kubectl logs deployment/oauth2-proxy
   Verify provider settings
   Check network connectivity to provider
```

#### Issue: Certificate Expiration
```
❌ Error: SSL certificate expired
✅ Solution: Renew certificates automatically
   kubectl get certificates
   cert-manager will auto-renew
   Check cert-manager status
```

#### Issue: Network Policy Blocking Traffic
```
❌ Error: Services cannot communicate
✅ Solution: Review network policies
   kubectl get networkpolicies
   Check policy rules
   Use kubectl describe for details
```

#### Issue: Vault Seal Status
```
❌ Error: Vault is sealed
✅ Solution: Unseal Vault
   vault operator unseal
   Provide unseal keys
   Check seal status
```

### Security Hardening Commands
```bash
# Run security assessment
./scripts/security-assessment.sh

# Update all security policies
./scripts/update-security-policies.sh

# Rotate all secrets
./scripts/rotate-secrets.sh

# Validate security configuration
./scripts/validate-security.sh
```

---

## 📋 Summary

TCA InfraForge's security implementation provides **enterprise-grade protection** with:

- **🛡️ Defense in Depth:** Multiple security layers working together
- **🔐 Zero-Trust Architecture:** Never trust, always verify
- **📜 Complete Audit Trail:** Full compliance and forensic capabilities
- **🚨 Automated Response:** Intelligent incident detection and response
- **📊 Continuous Monitoring:** Real-time security visibility

### Key Takeaways
1. **Security First:** Built into every layer of the architecture
2. **Compliance Ready:** Supports major compliance frameworks
3. **Automated Protection:** Intelligent threat detection and response
4. **Complete Visibility:** Full audit trail and monitoring
5. **Recovery Focused:** Comprehensive backup and disaster recovery

---

## 🔧 Implemented Security Hardening

TCA InfraForge automatically applies **production-ready security** to all deployments:

### Container Security
- **Non-root execution:** All containers run as non-root users
- **Read-only filesystems:** Prevents unauthorized file modifications
- **Dropped capabilities:** Removes unnecessary Linux capabilities
- **Security contexts:** Enforced for all pods and containers

### Resource Protection
- **CPU and memory limits:** Prevents resource exhaustion attacks
- **Requests and limits:** Ensures fair resource allocation
- **Pod disruption budgets:** Maintains availability during updates

### Network Security
- **Network policies:** Isolates traffic between services
- **TLS encryption:** Secures all communications
- **Ingress security:** Protects external access points

### Automated Security
All security measures are applied automatically through **Kustomize patches** - no manual configuration needed!

---

## 🎯 What's Next?

Now that you understand security, you're ready to:

1. **[☁️ Cloudflare Integration](./10-cloudflare-integration.md)** - Set up external access and protection
2. **[🛠️ Advanced Configuration](./11-performance-optimization.md)** - Fine-tune performance and security
3. **[⚙️ CI/CD Pipeline](./12-ci-cd-pipeline.md)** - Implement automated deployment pipelines

**💡 Pro Tip:** Security is not a one-time setup - it's an ongoing process. Regularly review your security posture, update policies, and conduct security assessments!

---

*Ready to connect your platform to the world? Let's move to the Cloudflare Integration chapter to set up secure external access!* ☁️
