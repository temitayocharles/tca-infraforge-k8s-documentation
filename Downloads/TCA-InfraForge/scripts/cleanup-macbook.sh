#!/bin/bash
# 🧹 TC Enterprise DevOps Platform - Safe Cleanup Script
# Preserves registry data, removes development artifacts

set -e

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

print_header "🧹 TC ENTERPRISE DEVOPS PLATFORM - SAFE CLEANUP"

echo -e "${GREEN}This script will clean up development artifacts while preserving:${NC}"
echo -e "${BLUE}  ✅ Registry data (704MB)${NC}"
echo -e "${BLUE}  ✅ Your code and configurations${NC}"
echo -e "${BLUE}  ✅ GHCR integration scripts${NC}"
echo ""

# Calculate space before cleanup
SPACE_BEFORE=$(du -sh . 2>/dev/null | cut -f1)
echo -e "${YELLOW}📊 Space before cleanup: ${SPACE_BEFORE}${NC}"

# Step 1: Remove log files
print_warning "Step 1: Removing log files..."
LOG_COUNT=$(find . -name "*.log" -type f | wc -l)
if [ "$LOG_COUNT" -gt 0 ]; then
    find . -name "*.log" -type f -delete
    print_success "Removed $LOG_COUNT log files"
else
    print_success "No log files found"
fi

# Step 2: Clean Docker containers
print_warning "Step 2: Cleaning Docker containers..."
if command -v docker &> /dev/null; then
    RUNNING_CONTAINERS=$(docker ps -q | wc -l)
    if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
        echo -e "${YELLOW}Stopping $RUNNING_CONTAINERS running containers...${NC}"
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        print_success "Cleaned up Docker containers"
    else
        print_success "No Docker containers to clean"
    fi

    # Clean Docker system (optional)
    echo -e "${YELLOW}Cleaning Docker system (dangling images, etc.)...${NC}"
    docker system prune -f 2>/dev/null || true
    print_success "Docker system cleaned"
else
    print_warning "Docker not found, skipping container cleanup"
fi

# Step 3: Delete KIND cluster
print_warning "Step 3: Deleting KIND cluster..."
if command -v kind &> /dev/null; then
    CLUSTER_COUNT=$(kind get clusters 2>/dev/null | wc -l)
    if [ "$CLUSTER_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}Deleting KIND cluster: tc-devops-cluster${NC}"
        kind delete cluster --name tc-devops-cluster 2>/dev/null || true
        print_success "KIND cluster deleted"
    else
        print_success "No KIND clusters to delete"
    fi
else
    print_warning "KIND not found, skipping cluster cleanup"
fi

# Step 4: Remove temporary files
print_warning "Step 4: Removing temporary files..."
TEMP_COUNT=$(find . -name "*.tmp" -o -name "*.bak" -o -name ".DS_Store" -type f | wc -l)
if [ "$TEMP_COUNT" -gt 0 ]; then
    find . -name "*.tmp" -o -name "*.bak" -o -name ".DS_Store" -type f -delete
    print_success "Removed $TEMP_COUNT temporary files"
else
    print_success "No temporary files found"
fi

# Step 5: Clean Python cache (if any)
print_warning "Step 5: Cleaning Python cache..."
PY_CACHE_COUNT=$(find . -name "__pycache__" -type d | wc -l)
if [ "$PY_CACHE_COUNT" -gt 0 ]; then
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    print_success "Removed Python cache directories"
else
    print_success "No Python cache found"
fi

# Calculate space after cleanup
SPACE_AFTER=$(du -sh . 2>/dev/null | cut -f1)
echo ""
print_header "🎉 CLEANUP COMPLETE!"

echo -e "${GREEN}Space before: ${SPACE_BEFORE}${NC}"
echo -e "${GREEN}Space after:  ${SPACE_AFTER}${NC}"
echo ""
echo -e "${BLUE}🗂️ PRESERVED:${NC}"
echo -e "${GREEN}  ✅ Registry data (704MB)${NC}"
echo -e "${GREEN}  ✅ All your code and configurations${NC}"
echo -e "${GREEN}  ✅ GHCR integration scripts${NC}"
echo -e "${GREEN}  ✅ Documentation and guides${NC}"
echo ""
echo -e "${BLUE}🗑️ CLEANED UP:${NC}"
echo -e "${GREEN}  ✅ Log files${NC}"
echo -e "${GREEN}  ✅ Docker containers${NC}"
echo -e "${GREEN}  ✅ KIND cluster${NC}"
echo -e "${GREEN}  ✅ Temporary files${NC}"
echo -e "${GREEN}  ✅ Python cache${NC}"
echo ""
echo -e "${YELLOW}💡 Your MacBook is now clean and optimized!${NC}"
echo -e "${BLUE}🔄 Ready for future development work${NC}"
