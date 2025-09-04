#!/bin/bash
# Enable Dual Registry Mode for TC Enterprise Platform
# Pushes images to both local registry and GHCR

echo "🔄 Enabling Dual Registry Mode"
echo "=============================="
echo ""

# Check if GitHub token is available
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ GITHUB_TOKEN environment variable not set"
    echo ""
    echo "Please set your GitHub token:"
    echo "export GITHUB_TOKEN=your_personal_access_token"
    echo ""
    echo "Get token from: https://github.com/settings/tokens"
    echo "Required scopes: read:packages, write:packages, delete:packages"
    exit 1
fi

# Enable GHCR in pipeline
export USE_GHCR=true

# Test GHCR authentication
echo "🔐 Testing GHCR authentication..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u temitayocharles --password-stdin 2>/dev/null

if [[ $? -eq 0 ]]; then
    echo "✅ GHCR authentication successful!"
    echo ""
    echo "🚀 Dual registry mode enabled!"
    echo "   • Primary: localhost:5001 (local registry)"
    echo "   • Secondary: ghcr.io/temitayocharles/ghcr (GitHub)"
    echo ""
    echo "📦 Run the pipeline:"
    echo "   ./tc-full-pipeline.sh"
    echo ""
    echo "Your processed images will be available:"
    echo "   • Locally: http://localhost:5001"
    echo "   • Globally: https://github.com/temitayocharles/ghcr"
else
    echo "❌ GHCR authentication failed"
    echo "Please check your token and try again"
    exit 1
fi
