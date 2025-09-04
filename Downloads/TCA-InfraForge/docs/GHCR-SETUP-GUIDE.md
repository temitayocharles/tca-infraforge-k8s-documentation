# 🚀 TC Enterprise DevOps Platform - GHCR Setup Guide
# GitHub Container Registry Integration

## 📋 Prerequisites

1. **GitHub Token**: Create a Personal Access Token at https://github.com/settings/tokens
   - Required scopes: `read:packages`, `write:packages`, `delete:packages`
   - Set as environment variable: `export GITHUB_TOKEN=your_token_here`

2. **Docker**: Ensure Docker is running and you have images to push

## 🔧 Setup Steps

### Step 1: Authenticate with GHCR
```bash
# Set your GitHub token
export GITHUB_TOKEN=your_github_token

# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u temitayocharles --password-stdin
```

### Step 2: Enable Dual Registry Mode
```bash
# Run the dual registry setup script
./enable-dual-registry.sh
```

This script will:
- ✅ Configure authentication for both registries
- ✅ Set up automatic image synchronization
- ✅ Update deployment manifests for hybrid usage
- ✅ Enable cross-machine image sharing

### Step 3: Push Your Images
```bash
# Run the automated dual-registry push script
./tc-full-pipeline.sh
```

This script will:
- ✅ Scan all your local Docker images
- ✅ Tag them for both local registry and GHCR
- ✅ Push to local registry (fast, private)
- ✅ Push to GHCR (global sharing, backup)
- ✅ Skip system images (k8s.gcr.io, etc.)

### Step 4: Verify Your Images
Visit: https://github.com/temitayocharles/tc-enterprise-devops-platform/packages

## 📦 Dual Registry Architecture

### Hybrid Workflow Overview

```
┌─────────────────┐    ┌─────────────────┐
│   Local Machine │    │   Remote/Team   │
│                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Local       │ │    │ │ GHCR        │ │
│ │ Registry    │◄┼────┼►│ Registry    │ │
│ │ (Fast)      │ │    │ │ (Global)    │ │
│ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘
         │                        │
         └────────────────────────┘
              Synchronization
```

### Image Naming Convention

Your images will be available in both registries:

**Local Registry (Fast Development):**
```
localhost:5001/tc-enterprise-devops-platform/image-name:tag
```

**GitHub Container Registry (Global Sharing):**
```
ghcr.io/temitayocharles/tc-enterprise-devops-platform/image-name:tag
```

Examples:
- `localhost:5001/tc-enterprise-devops-platform/tc-infrastructure-api:tc-v1.0-enterprise`
- `ghcr.io/temitayocharles/tc-enterprise-devops-platform/nginx:latest`

## 🚀 Using Dual Registry in Deployments

### Automatic Updates
Your deployment files have been automatically updated to use the hybrid approach:
- ✅ `config/tc-api-deployment.yaml` - Updated to use local registry primarily
- ✅ `tc-full-pipeline.sh` - Handles dual registry synchronization
- ✅ Other manifests use standard public images (no change needed)

### Smart Image Selection
The platform automatically selects the best registry based on context:

**Development/Local:**
```yaml
# Uses local registry for speed
image: localhost:5001/tc-enterprise-devops-platform/my-app:dev
```

**Production/Cross-Machine:**
```yaml
# Uses GHCR for reliability and sharing
image: ghcr.io/temitayocharles/tc-enterprise-devops-platform/my-app:v1.0
```

**Fallback Logic:**
```yaml
# Platform automatically falls back to GHCR if local registry unavailable
image: localhost:5001/tc-enterprise-devops-platform/my-app:v1.0
# If localhost:5001 fails → tries ghcr.io/temitayocharles/tc-enterprise-devops-platform/my-app:v1.0
```

## 🌍 Benefits of Dual Registry Setup

### Local Registry Benefits
- ✅ **Lightning Fast** - Sub-second image pulls locally
- ✅ **Zero Network Latency** - No internet dependency
- ✅ **Resource Efficient** - Minimal CPU/memory usage
- ✅ **Private** - Images stay on your machine
- ✅ **Always Available** - Works offline

### GHCR Benefits
- ✅ **Free** for public repositories
- ✅ **Unlimited storage**
- ✅ **Global CDN** - Fast pulls worldwide
- ✅ **Integrated** with GitHub (same auth, same repo)
- ✅ **Version control** - Images tied to your commits
- ✅ **Public access** - Share with the community
- ✅ **Backup** - Images preserved if local registry lost

### Combined Benefits
- ✅ **Best of Both Worlds** - Fast local + global sharing
- ✅ **Cross-Machine Sharing** - Share images between your Mac Mini and MacBook
- ✅ **Production Ready** - Reliable global distribution
- ✅ **Resource Conscious** - Minimal local resource usage
- ✅ **Automated** - Scripts handle synchronization

## 🔄 Hybrid Workflow Patterns

### Development Workflow
```bash
# 1. Develop locally with fast iterations
docker build -t my-app:dev .
docker tag my-app:dev localhost:5001/tc-enterprise-devops-platform/my-app:dev

# 2. Push to both registries when ready to share
./tc-full-pipeline.sh

# 3. Deploy locally (uses local registry)
kubectl apply -f deployment-local.yaml
```

### Production Workflow
```bash
# 1. Build and push to both registries
./tc-full-pipeline.sh

# 2. Deploy to production (can use GHCR for reliability)
kubectl apply -f deployment-prod.yaml

# 3. Share with team (available on GHCR)
# Team members can pull: docker pull ghcr.io/temitayocharles/tc-enterprise-devops-platform/my-app:v1.0
```

### Cross-Machine Sharing
```bash
# On Mac Mini (build machine)
./tc-full-pipeline.sh  # Pushes to both registries

# On MacBook (development machine)
# Automatically pulls from GHCR if local registry not available
kubectl apply -f deployment.yaml
```

## 📊 Monitoring Your Usage

### Local Registry
- **Status**: `./scripts/check-registry-status.sh`
- **Images**: `curl http://localhost:5001/v2/_catalog`
- **Storage**: Minimal impact (< 100MB typical)

### GHCR Usage
- **View packages**: https://github.com/temitayocharles/tc-enterprise-devops-platform/packages
- **Download stats**: Available in GitHub Insights
- **Storage usage**: Unlimited for public repos

## 🛠️ Troubleshooting

### Authentication Issues
```bash
# Re-login if token expires
echo $GITHUB_TOKEN | docker login ghcr.io -u temitayocharles --password-stdin

# Verify authentication
docker pull ghcr.io/temitayocharles/tc-enterprise-devops-platform/alpine:latest
```

### Dual Registry Issues
```bash
# Check local registry status
curl http://localhost:5001/v2/

# Test GHCR connectivity
docker pull ghcr.io/temitayocharles/tc-enterprise-devops-platform/alpine:latest

# Re-run dual registry setup
./enable-dual-registry.sh
```

### Permission Denied
- Ensure your GitHub token has the correct scopes
- Verify you're using the correct username
- Check if token has expired

### Image Not Found
- Check the exact image name in both registries
- Ensure the image was pushed successfully with `./tc-full-pipeline.sh`
- Verify the tag exists in both locations

### Synchronization Issues
```bash
# Manual sync if automatic sync fails
./tc-full-pipeline.sh --sync-only

# Check sync status
./scripts/check-sync-status.sh
```

## 🎉 Success!

Your enterprise platform now has:
- ✅ **Dual Registry Architecture** - Fast local + global sharing
- ✅ **Cross-Machine Collaboration** - Share images between devices
- ✅ **Production-Ready** - Reliable global distribution
- ✅ **Resource Efficient** - Minimal local resource usage
- ✅ **Automated Synchronization** - Seamless dual registry management
- ✅ **Community Sharing** - Public access capabilities

**Ready to deploy anywhere in the world with optimal performance!** 🌍

---

## 📚 Additional Resources

- [Main README](../README.md) - Platform overview and quick start
- [Architecture Documentation](../docs/02-architecture-overview.md) - Technical details
- [Troubleshooting Guide](../KUBERNETES-TROUBLESHOOTING.md) - Common issues and solutions
