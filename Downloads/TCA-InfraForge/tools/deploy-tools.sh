#!/bin/bash
echo "🚀 Deploying TC Enterprise Advanced Tools"
echo "Applying configurations..."

kubectl apply -f tools/jaeger-standalone.yaml --validate=false
kubectl apply -f tools/argocd-standalone.yaml --validate=false
kubectl apply -f tools/standalone-ingress.yaml --validate=false

echo "✅ Tools deployed!"
echo "Access:"
echo "• Jaeger: https://jaeger.temitayocharles.online"
echo "• ArgoCD: https://argocd.temitayocharles.online"
