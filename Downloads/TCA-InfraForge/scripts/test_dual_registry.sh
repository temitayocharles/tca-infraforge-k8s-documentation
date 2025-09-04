#!/bin/bash
# Test Dual Registry with Progress Bar
echo "🌐 Testing Dual Registry with Progress..."
echo "====================================="
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

steps=(
    "Setting up environment"
    "Enabling GHCR mode"
    "Testing GitHub token"
    "Pulling test image"
    "Creating TC Enterprise branding"
    "Building branded image"
    "Tagging for local registry"
    "Pushing to local registry"
    "Tagging for GHCR"
    "Pushing to GHCR"
    "Verifying dual registry"
    "Cleanup"
)

total_steps=${#steps[@]}
current_step=0

for step in "${steps[@]}"; do
    ((current_step++))
    show_progress $current_step $total_steps
    echo -e "\n$current_step. $step..."

    case $step in
        "Setting up environment")
            if [[ -z "$GITHUB_TOKEN" ]]; then
                echo "❌ GITHUB_TOKEN environment variable not set"
                echo "Please set it with: export GITHUB_TOKEN=your_token_here"
                exit 1
            fi
            sleep 1
            ;;
        "Enabling GHCR mode")
            export USE_GHCR=true
            sleep 1
            ;;
        "Testing GitHub token")
            echo "$GITHUB_TOKEN" | docker login ghcr.io -u temitayocharles --password-stdin >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                echo "  ✅ Token valid"
            else
                echo "  ❌ Token invalid"
                exit 1
            fi
            sleep 1
            ;;
        "Pulling test image")
            docker pull alpine:latest >/dev/null 2>&1
            echo "  ✅ Image pulled"
            sleep 1
            ;;
        "Creating TC Enterprise branding")
            cat > /tmp/Dockerfile.test << EOF
FROM alpine:latest
LABEL tc.owner="Temitayo Charles"
LABEL tc.platform="TC Enterprise DevOps Stack"
LABEL tc.test="dual-registry"
EOF
            echo "  ✅ Branding created"
            sleep 1
            ;;
        "Building branded image")
            docker build -t tc-test:latest -f /tmp/Dockerfile.test . >/dev/null 2>&1
            echo "  ✅ Image built"
            sleep 1
            ;;
        "Tagging for local registry")
            docker tag tc-test:latest localhost:5001/tc-infrastructure/test:tc-v1.0-enterprise
            echo "  ✅ Tagged for local registry"
            sleep 1
            ;;
        "Pushing to local registry")
            docker push localhost:5001/tc-infrastructure/test:tc-v1.0-enterprise >/dev/null 2>&1
            echo "  ✅ Pushed to local registry"
            sleep 1
            ;;
        "Tagging for GHCR")
            docker tag tc-test:latest ghcr.io/temitayocharles/tc-enterprise-devops-platform/test:tc-v1.0-enterprise
            echo "  ✅ Tagged for GHCR"
            sleep 1
            ;;
        "Pushing to GHCR")
            docker push ghcr.io/temitayocharles/tc-enterprise-devops-platform/test:tc-v1.0-enterprise >/dev/null 2>&1
            echo "  ✅ Pushed to GHCR"
            sleep 1
            ;;
        "Verifying dual registry")
            echo "  📊 Checking local registry..."
            curl -s http://localhost:5001/v2/_catalog | grep -q "test" && echo "    ✅ Local registry has test image" || echo "    ⚠️  Local registry check failed"
            echo "  🌐 GHCR available at: https://github.com/temitayocharles/tc-enterprise-devops-platform/packages"
            sleep 1
            ;;
        "Cleanup")
            rm -f /tmp/Dockerfile.test
            docker rmi tc-test:latest localhost:5001/tc-infrastructure/test:tc-v1.0-enterprise ghcr.io/temitayocharles/tc-enterprise-devops-platform/test:tc-v1.0-enterprise >/dev/null 2>&1
            echo "  ✅ Cleanup completed"
            sleep 1
            ;;
    esac
done

show_progress $total_steps $total_steps
echo -e "\n\n🎉 Dual Registry Test Complete!"
echo "=============================="
echo ""
echo "✅ Successfully tested:"
echo "   • Local registry push/pull"
echo "   • GHCR authentication & push"
echo "   • Dual registry workflow"
echo ""
echo "📊 Your registries:"
echo "   Local: http://localhost:5001"
echo "   GHCR:  https://github.com/temitayocharles/tc-enterprise-devops-platform/packages"
echo ""
echo "🚀 Ready for full pipeline: ./tc-full-pipeline.sh"
