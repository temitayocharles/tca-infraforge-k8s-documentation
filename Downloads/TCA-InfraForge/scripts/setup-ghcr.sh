#!/bin/bash
# GHCR Setup Script for TC Enterprise DevOps Platform
# Sets up GitHub Container Registry authentication and configuration

set -e

echo "🐙 Setting up GitHub Container Registry (GHCR) for TC Enterprise Platform"
echo "======================================================================"
echo ""

# Check if GitHub CLI is available
if command -v gh &>/dev/null; then
    echo "✅ GitHub CLI found"

    # Check if user is logged in
    if gh auth status &>/dev/null; then
        echo "✅ GitHub CLI authenticated"
        GITHUB_USER=$(gh api user -q .login)
        echo "👤 GitHub User: $GITHUB_USER"
    else
        echo "❌ GitHub CLI not authenticated"
        echo "Please run: gh auth login"
        exit 1
    fi
else
    echo "⚠️  GitHub CLI not found. Please install it first:"
    echo "   brew install gh  (macOS)"
    echo "   Or download from: https://cli.github.com/"
    exit 1
fi

# Get GitHub token
echo ""
echo "🔑 Getting GitHub Personal Access Token..."
echo "   This token needs 'packages' scope for GHCR access"
echo ""

# Try to get token from environment or prompt
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Option 1: Set environment variable:"
    echo "   export GITHUB_TOKEN=your_token_here"
    echo ""
    echo "Option 2: Create a new token at:"
    echo "   https://github.com/settings/tokens"
    echo "   Required scopes: 'read:packages', 'write:packages', 'delete:packages'"
    echo ""
    read -p "Enter your GitHub Personal Access Token: " -s GITHUB_TOKEN
    echo ""
fi

# Test token and login to GHCR
echo ""
echo "🔐 Logging into GitHub Container Registry..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin

if [[ $? -eq 0 ]]; then
    echo "✅ Successfully logged into GHCR!"
else
    echo "❌ Failed to login to GHCR"
    echo "Please check your token and try again"
    exit 1
fi

# Update tc-full-pipeline.sh to use GHCR
echo ""
echo "📝 Updating pipeline configuration for GHCR..."

# Backup original
cp tc-full-pipeline.sh tc-full-pipeline.sh.backup 2>/dev/null || true

# Update registry URL
sed -i.bak "s|REGISTRY=\"localhost:5001\"|REGISTRY=\"localhost:5001\"|" tc-full-pipeline.sh
sed -i.bak "s|USE_GHCR=false|USE_GHCR=true|" tc-full-pipeline.sh
sed -i.bak "s|GHCR_REGISTRY=\"ghcr.io/temitayocharles\"|GHCR_REGISTRY=\"ghcr.io/temitayocharles\"|" tc-full-pipeline.sh

echo "✅ Pipeline updated to use dual registry mode!"
echo ""
echo "🚀 Ready to run the pipeline:"
echo "   ./tc-full-pipeline.sh"
echo ""
echo "📦 Your images will be available at:"
echo "   https://github.com/$GITHUB_USER?tab=packages"
echo ""
echo "🔒 Security Notes:"
echo "   • Images are private by default"
echo "   • Access controlled by GitHub repository permissions"
echo "   • GitHub's vulnerability scanning is available"
echo "   • Consider enabling Dependabot for security updates"
echo ""

# Test registry access
echo "🧪 Testing GHCR access..."
if curl -f -s -H "Authorization: Bearer $GITHUB_TOKEN" \
    "https://ghcr.io/v2/$GITHUB_USER/tc-enterprise/nginx/tags/list" &>/dev/null; then
    echo "✅ GHCR access confirmed"
else
    echo "ℹ️  GHCR access test inconclusive (expected if no images exist yet)"
fi

echo ""
echo "🎉 GHCR setup complete!"
