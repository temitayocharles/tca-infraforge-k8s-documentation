#!/bin/bash
set -euo pipefail

PROFILE="standard"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"; }

log "Cleaning up ${PROFILE} profile deployment..."

# Delete KIND cluster
if kind get clusters | grep -q "tca-infraforge-${PROFILE}"; then
    log "Deleting Kubernetes cluster..."
    kind delete cluster --name "tca-infraforge-${PROFILE}"
fi

# Stop Docker Compose
if [ -f "templates/docker-compose/infrastructure-${PROFILE}.yaml" ]; then
    log "Stopping external infrastructure..."
    docker-compose -f "templates/docker-compose/infrastructure-${PROFILE}.yaml" down -v
fi

# Clean up Docker resources
log "Cleaning up Docker resources..."
docker system prune -f --volumes

log "🧹 Cleanup complete for ${PROFILE} profile!"
