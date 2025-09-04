#!/bin/bash
echo "🔑 GitHub Token Setup for Dual Registry"
echo "======================================"
echo ""
echo "Please paste your GitHub token:"
read -s TOKEN
echo ""
export GITHUB_TOKEN="$TOKEN"
echo "✅ Token set in environment"
echo ""
echo "🔐 Testing GitHub authentication..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u temitayocharles --password-stdin 2>/dev/null
if [[ $? -eq 0 ]]; then
    echo "✅ Authentication successful!"
    echo ""
    echo "🚀 Running dual registry setup..."
    ./enable-dual-registry.sh
else
    echo "❌ Authentication failed"
    echo "Please check your token and try again"
    exit 1
fi
