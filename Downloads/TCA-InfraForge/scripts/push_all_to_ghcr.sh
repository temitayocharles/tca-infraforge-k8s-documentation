#!/bin/bash
# Push All Images to GHCR with Progress Bar
echo "🌍 Pushing All Images to GHCR with Progress..."
echo "=============================================="
echo ""

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))

    printf "\rProgress: ["
    for ((i=1; i<=completed; i++)); do printf "="; done
    for ((i=completed+1; i<=width; i++)); do printf " "; done
    printf "] %d%% (%d/%d)" $percentage $current $total
}

# Get all images from local registry
echo "📊 Gathering images from local registry..."
IMAGES=$(curl -s http://localhost:5001/v2/_catalog | jq -r '.repositories[]' 2>/dev/null || curl -s http://localhost:5001/v2/_catalog | grep -o '"[^"]*"' | tr -d '"')

# Convert to array
IFS=$'\n' read -r -d '' -a IMAGES_ARRAY <<< "$IMAGES"
TOTAL_IMAGES=${#IMAGES_ARRAY[@]}

echo "Found $TOTAL_IMAGES images to push to GHCR"
echo ""

# Set GitHub token if not set
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ GITHUB_TOKEN environment variable not set"
    echo "Please set it with: export GITHUB_TOKEN=your_token_here"
    exit 1
fi

# Authenticate with GHCR
echo "🔐 Authenticating with GHCR..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u temitayocharles --password-stdin >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "❌ GHCR authentication failed"
    exit 1
fi
echo "✅ GHCR authentication successful"
echo ""

PROCESSED=0
FAILED=0

for img in "${IMAGES_ARRAY[@]}"; do
    ((PROCESSED++))
    show_progress $PROCESSED $TOTAL_IMAGES
    echo -e "\n$PROCESSED/$TOTAL_IMAGES Pushing: $img"

    # Pull from local registry
    if docker pull localhost:5001/$img:tc-v1.0-enterprise >/dev/null 2>&1; then
        echo "  📥 Pulled from local registry"

        # Tag for GHCR
        docker tag localhost:5001/$img:tc-v1.0-enterprise ghcr.io/temitayocharles/tc-enterprise-devops-platform/$img:tc-v1.0-enterprise
        echo "  🏷️  Tagged for GHCR"

        # Push to GHCR
        if docker push ghcr.io/temitayocharles/tc-enterprise-devops-platform/$img:tc-v1.0-enterprise >/dev/null 2>&1; then
            echo "  ✅ Successfully pushed to GHCR"
        else
            echo "  ❌ Failed to push to GHCR"
            ((FAILED++))
        fi
    else
        echo "  ❌ Failed to pull from local registry"
        ((FAILED++))
    fi

    echo ""
done

show_progress $TOTAL_IMAGES $TOTAL_IMAGES
echo -e "\n\n🎉 GHCR Push Complete!"
echo "====================="
echo ""
echo "📊 Results:"
echo "   • Total images: $TOTAL_IMAGES"
echo "   • Successfully pushed: $((TOTAL_IMAGES - FAILED))"
echo "   • Failed: $FAILED"
echo ""
echo "🌍 Your images are now available globally at:"
echo "   https://github.com/temitayocharles/tc-enterprise-devops-platform/packages"
echo ""
echo "💡 Note: Packages may be private by default"
echo "   To make them public, visit the packages page and change visibility settings"
echo ""
echo "🔄 Cross-machine sharing is now enabled!"
echo "   Other devices can pull: docker pull ghcr.io/temitayocharles/tc-enterprise-devops-platform/[image-name]:tc-v1.0-enterprise"
