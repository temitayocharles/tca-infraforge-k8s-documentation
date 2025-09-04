#!/bin/bash

# Tunnel Management Script
# Use this to manage the Cloudflare tunnel service

case "$1" in
    start)
        echo "Starting Cloudflare tunnel service..."
        launchctl load ~/Library/LaunchAgents/com.temitayocharles.cloudflared.plist
        sleep 2
        if pgrep -f "cloudflared tunnel run" > /dev/null; then
            echo "✅ Tunnel service started successfully"
        else
            echo "❌ Failed to start tunnel service"
        fi
        ;;
    stop)
        echo "Stopping Cloudflare tunnel service..."
        launchctl unload ~/Library/LaunchAgents/com.temitayocharles.cloudflared.plist
        sleep 2
        if ! pgrep -f "cloudflared tunnel run" > /dev/null; then
            echo "✅ Tunnel service stopped successfully"
        else
            echo "❌ Failed to stop tunnel service"
        fi
        ;;
    restart)
        echo "Restarting Cloudflare tunnel service..."
        launchctl unload ~/Library/LaunchAgents/com.temitayocharles.cloudflared.plist
        sleep 2
        launchctl load ~/Library/LaunchAgents/com.temitayocharles.cloudflared.plist
        sleep 3
        if pgrep -f "cloudflared tunnel run" > /dev/null; then
            echo "✅ Tunnel service restarted successfully"
        else
            echo "❌ Failed to restart tunnel service"
        fi
        ;;
    status)
        if pgrep -f "cloudflared tunnel run" > /dev/null; then
            echo "✅ Tunnel service is running"
            ps aux | grep "cloudflared tunnel run" | grep -v grep
        else
            echo "❌ Tunnel service is not running"
        fi
        ;;
    logs)
        echo "=== Tunnel Logs ==="
        if [ -f ~/Library/Logs/cloudflared.error.log ]; then
            tail -20 ~/Library/Logs/cloudflared.error.log
        else
            echo "No log file found"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo
        echo "Commands:"
        echo "  start   - Start the tunnel service"
        echo "  stop    - Stop the tunnel service"
        echo "  restart - Restart the tunnel service"
        echo "  status  - Check tunnel service status"
        echo "  logs    - Show recent tunnel logs"
        ;;
esac
