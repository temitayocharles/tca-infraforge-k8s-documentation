#!/bin/bash
# 🔄 Update Deployment Images to Use GHCR
# This script updates Kubernetes manifests to use GHCR instead of local registry

set -e

# Configuration
GITHUB_USER="temitayocharles"
GITHUB_REPO="tc-enterprise-devops-platform"
REGISTRY_URL="ghcr.io/${GITHUB_USER}/${GITHUB_REPO}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 UPDATING DEPLOYMENT IMAGES FOR GHCR${NC}"
echo "=========================================="

# Update the custom API image
if [ -f "config/tc-api-deployment.yaml" ]; then
    echo -e "${YELLOW}Updating config/tc-api-deployment.yaml...${NC}"
    sed -i.bak "s|localhost:5000/tc-infrastructure/api:tc-v1.0-enterprise|${REGISTRY_URL}/tc-infrastructure-api:tc-v1.0-enterprise|g" config/tc-api-deployment.yaml
    echo -e "${GREEN}✅ Updated tc-api-deployment.yaml${NC}"
fi

# Check for any other localhost registry references
echo -e "${YELLOW}Checking for other local registry references...${NC}"
local_refs=$(grep -r "localhost:5000" --include="*.yaml" --include="*.yml" . | wc -l)

if [ "$local_refs" -gt 0 ]; then
    echo -e "${YELLOW}Found $local_refs local registry references. Please review:${NC}"
    grep -r "localhost:5000" --include="*.yaml" --include="*.yml" .
else
    echo -e "${GREEN}✅ No additional local registry references found${NC}"
fi

echo ""
echo -e "${BLUE}📋 GHCR INTEGRATION SUMMARY${NC}"
echo "================================"
echo -e "${GREEN}✅ Custom images updated to use GHCR${NC}"
echo -e "${GREEN}✅ Standard images (nginx, postgres, etc.) remain unchanged${NC}"
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "  1. Push your custom images to GHCR using: ./push-to-ghcr.sh"
echo "  2. Deploy using your updated manifests"
echo "  3. Images will be available globally via GHCR"
echo ""
echo -e "${BLUE}🔗 GHCR Registry URL: ${REGISTRY_URL}${NC}"
echo -e "${BLUE}📦 View packages at: https://github.com/${GITHUB_USER}/${GITHUB_REPO}/packages${NC}"
