#!/bin/bash
# Complete Dual Registry Setup Guide for TC Enterprise Platform
# This script guides you through setting up GitHub token and dual registry

echo "🚀 TC Enterprise DevOps Platform - Dual Registry Setup"
echo "======================================================"
echo ""
echo "This setup enables:"
echo "✅ Fast local development (localhost:5001)"
echo "✅ Global image sharing (ghcr.io)"
echo "✅ Cross-machine collaboration"
echo "✅ Automatic synchronization"
echo ""
echo "📋 Prerequisites Check"
echo "======================"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi
echo "✅ Docker is running"

# Check if local registry is accessible
if curl -s http://localhost:5001/v2/ >/dev/null; then
    echo "✅ Local registry is accessible (localhost:5001)"
else
    echo "⚠️  Local registry not detected. It will be created during deployment."
fi

echo ""
echo "🔑 GitHub Token Setup"
echo "===================="
echo ""
echo "You need a GitHub Personal Access Token with these scopes:"
echo "• read:packages    - Pull images from GHCR"
echo "• write:packages   - Push images to GHCR"
echo "• delete:packages  - Clean up old images"
echo ""
echo "📝 Step-by-step token creation:"
echo "1. Go to: https://github.com/settings/tokens"
echo "2. Click 'Generate new token (classic)'"
echo "3. Name: 'TC Enterprise GHCR Access'"
echo "4. Expiration: No expiration (recommended)"
echo "5. Check the required scopes above"
echo "6. Click 'Generate token'"
echo "7. COPY the token immediately (you won't see it again!)"
echo ""
read -p "Do you have your GitHub token ready? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Please create your token first, then run this script again."
    echo "Opening GitHub tokens page in your browser..."
    open "https://github.com/settings/tokens"
    exit 0
fi

# Get the token
echo ""
echo "Enter your GitHub Personal Access Token:"
echo "(It will be stored as an environment variable)"
echo ""
read -s -p "Token: " GITHUB_TOKEN
echo ""

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ No token provided. Exiting."
    exit 1
fi

# Export for current session
export GITHUB_TOKEN
echo "✅ Token set for current session"

# Test the token
echo ""
echo "🔐 Testing GitHub token..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u temitayocharles --password-stdin >/dev/null 2>&1

if [[ $? -eq 0 ]]; then
    echo "✅ GitHub token authentication successful!"
else
    echo "❌ GitHub token authentication failed"
    echo ""
    echo "Possible issues:"
    echo "• Token is incorrect or expired"
    echo "• Missing required scopes"
    echo "• Network connectivity issues"
    echo ""
    echo "Please check your token and try again."
    exit 1
fi

# Create .env file for persistence
echo ""
echo "💾 Saving configuration..."
cat > .ghcr-env << EOF
# GitHub Container Registry Configuration
# Created: $(date)
export GITHUB_TOKEN="$GITHUB_TOKEN"
export USE_GHCR=true
export GHCR_REGISTRY="ghcr.io/temitayocharles/tc-enterprise-devops-platform"
export LOCAL_REGISTRY="localhost:5001"
EOF

echo "✅ Configuration saved to .ghcr-env"
echo "   Load it in future sessions with: source .ghcr-env"

# Test dual registry setup
echo ""
echo "🔄 Testing dual registry setup..."

# Test local registry
if curl -s http://localhost:5001/v2/ >/dev/null; then
    echo "✅ Local registry: Available"
else
    echo "⚠️  Local registry: Not yet available (will be created during deployment)"
fi

# Test GHCR
if docker pull ghcr.io/temitayocharles/tc-enterprise-devops-platform/alpine:latest >/dev/null 2>&1; then
    echo "✅ GHCR: Available and accessible"
else
    echo "⚠️  GHCR: Not yet populated (will be populated when you run the pipeline)"
fi

echo ""
echo "🎉 Dual Registry Setup Complete!"
echo "================================"
echo ""
echo "Your platform now supports:"
echo ""
echo "🏠 Local Registry (Primary)"
echo "   URL: localhost:5001"
echo "   Use: Fast development and local deployments"
echo "   Status: $(curl -s http://localhost:5001/v2/ >/dev/null && echo '✅ Active' || echo '⏳ Will activate on deployment')"
echo ""
echo "🌍 GitHub Container Registry (Secondary)"
echo "   URL: ghcr.io/temitayocharles/tc-enterprise-devops-platform"
echo "   Use: Global sharing and cross-machine access"
echo "   Status: ✅ Configured and authenticated"
echo ""
echo "🚀 Next Steps:"
echo "=============="
echo ""
echo "1. Deploy your platform (if not already done):"
echo "   ./enterprise-lab-orchestrator.sh"
echo ""
echo "2. Push images to both registries:"
echo "   ./tc-full-pipeline.sh"
echo ""
echo "3. Verify your images:"
echo "   • Local: curl http://localhost:5001/v2/_catalog"
echo "   • GHCR: https://github.com/temitayocharles/tc-enterprise-devops-platform/packages"
echo ""
echo "4. For future sessions, load your config:"
echo "   source .ghcr-env"
echo ""
echo "📚 Documentation:"
echo "• Main Guide: README.md"
echo "• GHCR Setup: GHCR-SETUP-GUIDE.md"
echo "• Troubleshooting: KUBERNETES-TROUBLESHOOTING.md"
echo ""
echo "Happy deploying! 🎉"</content>
<parameter name="filePath">/Volumes/256-B/tc-enterprise-devops-platform-main/setup-dual-registry.sh
