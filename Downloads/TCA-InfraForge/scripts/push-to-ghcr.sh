#!/bin/bash
# 🚀 TC Enterprise DevOps Platform - Push Images to GHCR
# This script pushes your local registry images to GitHub Container Registry

set -e

# Configuration
GITHUB_USER="temitayocharles"
GITHUB_REPO="tc-enterprise-devops-platform"
REGISTRY_URL="ghcr.io/${GITHUB_USER}/${GITHUB_REPO}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
    print_error "GITHUB_TOKEN environment variable is not set!"
    echo -e "${YELLOW}Please set your GitHub token:${NC}"
    echo "export GITHUB_TOKEN=your_github_token_here"
    echo ""
    echo -e "${BLUE}Get your token from: https://github.com/settings/tokens${NC}"
    echo -e "${BLUE}Required scopes: read:packages, write:packages, delete:packages${NC}"
    exit 1
fi

print_header "🚀 PUSHING IMAGES TO GITHUB CONTAINER REGISTRY"

# Login to GHCR
print_warning "Logging into GitHub Container Registry..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin

if [ $? -eq 0 ]; then
    print_success "Successfully logged into GHCR"
else
    print_error "Failed to login to GHCR"
    exit 1
fi

# Get list of images from local registry
print_warning "Scanning local Docker images..."
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -v "REPOSITORY" | while read repo tag size; do
    # Skip k8s system images and none images
    if [[ $repo == "<none>" || $repo == *"k8s.gcr.io"* || $repo == *"kubernetesui"* ]]; then
        continue
    fi
    
    # Create GHCR tag
    image_name=$(basename "$repo" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')
    ghcr_tag="${REGISTRY_URL}/${image_name}:${tag}"
    
    echo ""
    print_warning "Processing: $repo:$tag ($size)"
    
    # Tag the image for GHCR
    if docker tag "$repo:$tag" "$ghcr_tag"; then
        print_success "Tagged: $ghcr_tag"
        
        # Push to GHCR
        if docker push "$ghcr_tag"; then
            print_success "Pushed: $ghcr_tag"
        else
            print_error "Failed to push: $ghcr_tag"
        fi
    else
        print_error "Failed to tag: $repo:$tag"
    fi
done

echo ""
print_header "🎉 PUSH COMPLETE!"
echo -e "${GREEN}Your images are now available at:${NC}"
echo -e "${BLUE}https://github.com/${GITHUB_USER}/${GITHUB_REPO}/packages${NC}"
echo ""
echo -e "${YELLOW}To use these images in your deployments, update your YAML files:${NC}"
echo -e "${BLUE}image: ${REGISTRY_URL}/your-image-name:tag${NC}"
echo ""
print_success "GHCR integration setup complete!"
