#!/bin/bash

echo "🚀 TC ENTERPRISE DEVOPS PLATFORM - STARTUP SCRIPT"
echo "================================================"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "1️⃣ Checking prerequisites..."
if ! command_exists cloudflared; then
    echo "❌ cloudflared not found. Please install Cloudflare tunnel."
    exit 1
fi

if ! command_exists kubectl; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Start Cloudflare tunnel
echo "2️⃣ Starting Cloudflare tunnel..."
pkill -f cloudflared 2>/dev/null || true
sleep 2
cloudflared tunnel run temitayocharles-tunnel &
TUNNEL_PID=$!
echo "✅ Tunnel started (PID: $TUNNEL_PID)"
sleep 5

# Start port forwarding
echo "3️⃣ Starting port forwarding..."

# Kill existing port forwarding
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 2

# Start Jaeger
export KUBECONFIG=/tmp/kind-config-3node.yaml
kubectl port-forward svc/jaeger-service 16686:16686 --address 0.0.0.0 &
JAEGER_PID=$!
echo "✅ Jaeger port forwarding started (PID: $JAEGER_PID)"

# Start ArgoCD
kubectl port-forward svc/argocd-service 8081:8080 --address 0.0.0.0 &
ARGOCD_PID=$!
echo "✅ ArgoCD port forwarding started (PID: $ARGOCD_PID)"

echo ""
echo "🎉 STARTUP COMPLETE!"
echo "==================="
echo ""
echo "🌐 Your Enterprise Tools:"
echo "   • Jaeger:  https://jaeger.temitayocharles.online"
echo "   • ArgoCD:  https://argocd.temitayocharles.online"
echo ""
echo "🔧 Local Access:"
echo "   • Jaeger:  http://localhost:16686"
echo "   • ArgoCD:  http://localhost:8081"
echo ""
echo "💡 Process IDs:"
echo "   • Tunnel:  $TUNNEL_PID"
echo "   • Jaeger:  $JAEGER_PID"
echo "   • ArgoCD:  $ARGOCD_PID"
echo ""
echo "🛑 To stop: kill $TUNNEL_PID $JAEGER_PID $ARGOCD_PID"
echo ""
echo "🌐 Opening browser..."
open https://jaeger.temitayocharles.online
sleep 2
open https://argocd.temitayocharles.online

echo ""
echo "✅ Ready! Test the URLs above."
