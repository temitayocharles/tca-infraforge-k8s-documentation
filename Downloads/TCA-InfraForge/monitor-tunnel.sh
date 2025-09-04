#!/bin/bash

# Cloudflare Tunnel and DNS Monitoring Script
# This script monitors DNS propagation and tunnel status

echo "=== Cloudflare Tunnel & DNS Monitoring ==="
echo "Timestamp: $(date)"
echo

# Check tunnel service status
echo "=== Tunnel Service Status ==="
if pgrep -f "cloudflared tunnel run" > /dev/null; then
    echo "✅ Tunnel service is running"
    ps aux | grep "cloudflared tunnel run" | grep -v grep
else
    echo "❌ Tunnel service is not running"
fi
echo

# Check DNS propagation
echo "=== DNS Propagation Status ==="
DOMAINS=(
    "argocd.temitayocharles.com"
    "grafana.temitayocharles.com"
    "prometheus.temitayocharles.com"
    "jaeger.temitayocharles.com"
    "kibana.temitayocharles.com"
    "faas.temitayocharles.com"
)

for domain in "${DOMAINS[@]}"; do
    result=$(dig +short "$domain" 2>/dev/null)
    if [ -n "$result" ]; then
        echo "✅ $domain: $result"
    else
        echo "⏳ $domain: Not propagated yet"
    fi
done
echo

# Test HTTP connectivity (only if DNS is propagated)
echo "=== HTTP Connectivity Test ==="
for domain in "${DOMAINS[@]}"; do
    if dig +short "$domain" > /dev/null 2>&1; then
        echo -n "$domain: "
        if curl -I --connect-timeout 5 --max-time 10 "https://$domain" 2>/dev/null | grep -q "HTTP/"; then
            echo "✅ Accessible"
        else
            echo "❌ Connection failed"
        fi
    else
        echo "$domain: ⏳ DNS not propagated yet"
    fi
done
echo

# Check tunnel logs
echo "=== Recent Tunnel Logs ==="
if [ -f ~/Library/Logs/cloudflared.error.log ]; then
    tail -5 ~/Library/Logs/cloudflared.error.log
else
    echo "No log file found"
fi

echo
echo "=== Next Steps ==="
echo "1. DNS propagation typically takes 24-48 hours"
echo "2. Run this script periodically to monitor progress"
echo "3. Once DNS propagates, test full access to all tools"
