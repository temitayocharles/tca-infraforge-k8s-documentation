# Enterprise DevOps Platform - Security Setup Guide
# This guide covers OAuth2 authentication for ArgoCD and Cloudflare Access setup

## 🔐 Phase 1: ArgoCD OAuth2 Setup

### Step 1: Create GitHub OAuth App
1. Go to: https://github.com/settings/applications/new
2. Fill in the details:
   - **Application name**: "TC Enterprise ArgoCD"
   - **Homepage URL**: `https://argocd.temitayocharles.online`
   - **Authorization callback URL**: `https://argocd.temitayocharles.online/login`
   - **Description**: "ArgoCD authentication for TC Enterprise DevOps Platform"

3. Click "Register application"
4. **Save the Client ID and Client Secret** (you'll need these)

### Step 2: Update ArgoCD OAuth2 Credentials
```bash
# Replace with your actual GitHub OAuth app credentials
kubectl patch secret argocd-secret -n argocd --type merge -p '{
  "data": {
    "oidc.github.clientId": "'$(echo -n "your-actual-client-id" | base64)'",
    "oidc.github.clientSecret": "'$(echo -n "your-actual-client-secret" | base64)'"
  }
}'
```

### Step 3: Configure RBAC for Your Teams
```bash
# Update with your actual GitHub org and team names
kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p '{
  "data": {
    "policy.csv": "g, your-github-org:admin-team, role:admin\ng, your-github-org:dev-team, role:developer\ng, your-github-org:readonly-team, role:readonly",
    "policy.default": "role:readonly"
  }
}'
```

### Step 4: Restart ArgoCD
```bash
kubectl rollout restart deployment argocd-server -n argocd
```

## 🛡️ Phase 2: Cloudflare Access Setup

### Step 1: Enable Cloudflare Zero Trust
1. Go to: https://dash.cloudflare.com/
2. Navigate to **Zero Trust** section
3. Click **"Get Started"** if not already enabled

### Step 2: Configure Identity Provider
1. Go to: Zero Trust → Settings → Authentication
2. Click **"Add"** next to GitHub
3. Enter your GitHub OAuth App credentials:
   - **Name**: "GitHub OAuth"
   - **Client ID**: Your GitHub OAuth App Client ID
   - **Client Secret**: Your GitHub OAuth App Client Secret
   - **Scopes**: `read:user`, `user:email`, `read:org`

### Step 3: Create Access Applications

#### ArgoCD Application:
1. Go to: Zero Trust → Access → Applications
2. Click **"Add an Application"**
3. Choose **"Self-hosted"**
4. Configure:
   - **Application name**: "TC Enterprise ArgoCD"
   - **Session Duration**: 24 hours
   - **Domain**: `argocd.temitayocharles.online`

#### Create Policies:
- **Admin Policy**:
  - Include: Your email + GitHub admin team
  - Require: Managed device posture
- **Developer Policy**:
  - Include: GitHub developer teams
  - Require: WARP client

### Step 4: Set Up Device Posture
1. Go to: Zero Trust → Settings → Device Posture
2. Create policies for:
   - **Managed Devices**: Require specific device certificates
   - **WARP Client**: Require Cloudflare WARP installation

### Step 5: Configure Gateway (DNS Filtering)
1. Go to: Zero Trust → Gateway → Policies
2. Create policies to:
   - Block malicious domains
   - Allow necessary DevOps tools (Docker, GitHub, etc.)

### Step 6: Deploy WARP Client
1. Go to: Zero Trust → Settings → WARP Client
2. Download and distribute WARP client to your team
3. Configure auto-connect and captive portal detection

## 🔍 Phase 3: Testing & Validation

### Test OAuth2 Login:
```bash
# Access ArgoCD
open https://argocd.temitayocharles.online

# Should redirect to GitHub for authentication
# After login, you should see ArgoCD dashboard
```

### Test Cloudflare Access:
```bash
# Test with WARP client connected
curl -I https://argocd.temitayocharles.online

# Should return 200 OK if authenticated
# Should return 302 redirect to login if not authenticated
```

### Validate Security:
```bash
# Check ArgoCD authentication
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}'

# Check Cloudflare tunnel
cloudflared tunnel list

# Test external access
curl -H "Authorization: Bearer <your-token>" https://argocd.temitayocharles.online/api/v1/applications
```

## 🚨 Security Best Practices

### 1. Regular Credential Rotation
- Rotate GitHub OAuth secrets every 90 days
- Use strong, unique passwords
- Enable 2FA everywhere

### 2. Access Reviews
- Review user access quarterly
- Remove inactive users immediately
- Implement least privilege principle

### 3. Monitoring & Alerting
- Enable Cloudflare Access logs
- Monitor failed login attempts
- Set up alerts for suspicious activity

### 4. Emergency Access
- Configure break-glass access for emergencies
- Require approval for emergency access
- Document emergency procedures

### 5. Backup Access
- Maintain alternative authentication methods
- Document manual override procedures
- Test backup access regularly

## 📊 Security Dashboard

Monitor these metrics:
- Failed login attempts
- Unusual access patterns
- Device posture compliance
- Application access logs

## 🆘 Troubleshooting

### OAuth2 Issues:
```bash
# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# Verify OAuth2 configuration
kubectl get configmap argocd-cm -n argocd -o yaml
```

### Cloudflare Access Issues:
```bash
# Check tunnel status
cloudflared tunnel list

# Verify DNS records
dig argocd.temitayocharles.online

# Check Cloudflare Access logs
# Go to: Zero Trust → Logs
```

## 🎯 Next Steps

1. ✅ Complete GitHub OAuth App setup
2. ✅ Configure Cloudflare Access applications
3. ✅ Test authentication flow
4. ✅ Deploy WARP client to team
5. ✅ Set up monitoring and alerts
6. ✅ Document security procedures

Your enterprise platform will now have enterprise-grade security! 🔐
