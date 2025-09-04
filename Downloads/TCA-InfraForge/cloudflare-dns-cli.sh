#!/bin/bash

# Cloudflare DNS Management Script
# Manage DNS records via Cloudflare API

# Configuration - Update these with your values
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-your-api-token-here}"
CLOUDFLARE_API_KEY="${CLOUDFLARE_API_KEY:-your-global-api-key-here}"
CLOUDFLARE_EMAIL="${CLOUDFLARE_EMAIL:-your-email@example.com}"
ZONE_ID="${CLOUDFLARE_ZONE_ID:-your-zone-id-here}"
DOMAIN="temitayocharles.online"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to make API calls
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3

    if [ "$CLOUDFLARE_API_TOKEN" != "your-api-token-here" ] && [ -n "$CLOUDFLARE_API_TOKEN" ]; then
        curl -s -X "$method" \
             "https://api.cloudflare.com/client/v4$endpoint" \
             -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
             -H "Content-Type: application/json" \
             ${data:+-d "$data"}
    else
        curl -s -X "$method" \
             "https://api.cloudflare.com/client/v4$endpoint" \
             -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
             -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
             -H "Content-Type: application/json" \
             ${data:+-d "$data"}
    fi
}

# Function to get zone ID
get_zone_id() {
    if [ "$ZONE_ID" = "your-zone-id-here" ]; then
        echo -e "${YELLOW}Zone ID not configured. Getting zone ID for $DOMAIN...${NC}"
        local response=$(api_call "GET" "/zones?name=$DOMAIN")
        ZONE_ID=$(echo "$response" | jq -r '.result[0].id' 2>/dev/null)

        if [ "$ZONE_ID" = "null" ] || [ -z "$ZONE_ID" ]; then
            echo -e "${RED}Failed to get zone ID. Please check your domain and API token.${NC}"
            return 1
        fi

        echo -e "${GREEN}Found Zone ID: $ZONE_ID${NC}"
        echo "Add this to your environment: export CLOUDFLARE_ZONE_ID=$ZONE_ID"
    fi
    return 0
}

# Function to list DNS records
list_dns_records() {
    echo -e "${BLUE}=== Current DNS Records for $DOMAIN ===${NC}"
    local response=$(api_call "GET" "/zones/$ZONE_ID/dns_records")
    echo "$response" | jq -r '.result[] | "\(.name) \(.type) \(.content) \(.proxied)"' 2>/dev/null || echo "$response"
}

# Function to create DNS record
create_dns_record() {
    local name=$1
    local type=$2
    local content=$3
    local proxied=${4:-true}

    echo -e "${BLUE}Creating DNS record: $name ($type) -> $content${NC}"

    local data="{
        \"type\": \"$type\",
        \"name\": \"$name\",
        \"content\": \"$content\",
        \"proxied\": $proxied
    }"

    local response=$(api_call "POST" "/zones/$ZONE_ID/dns_records" "$data")
    local success=$(echo "$response" | jq -r '.success' 2>/dev/null)

    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✅ DNS record created successfully${NC}"
    else
        echo -e "${RED}❌ Failed to create DNS record${NC}"
        echo "$response" | jq -r '.errors[]?.message' 2>/dev/null
    fi
}

# Function to delete DNS record
delete_dns_record() {
    local record_id=$1

    echo -e "${BLUE}Deleting DNS record ID: $record_id${NC}"
    local response=$(api_call "DELETE" "/zones/$ZONE_ID/dns_records/$record_id")
    local success=$(echo "$response" | jq -r '.success' 2>/dev/null)

    if [ "$success" = "true" ]; then
        echo -e "${GREEN}✅ DNS record deleted successfully${NC}"
    else
        echo -e "${RED}❌ Failed to delete DNS record${NC}"
    fi
}

# Function to create all tunnel DNS records
create_tunnel_records() {
    echo -e "${BLUE}=== Creating Tunnel DNS Records ===${NC}"

    # Get tunnel ID
    local tunnel_response=$(cloudflared tunnel list 2>/dev/null | grep temitayocharles-tunnel)
    local tunnel_id=$(echo "$tunnel_response" | awk '{print $1}')

    if [ -z "$tunnel_id" ]; then
        echo -e "${RED}❌ Could not find tunnel ID. Make sure tunnel exists.${NC}"
        return 1
    fi

    echo -e "${GREEN}Using Tunnel ID: $tunnel_id${NC}"

    # Create CNAME records for all subdomains
    local subdomains=("argocd" "grafana" "prometheus" "jaeger" "kibana" "faas")

    for subdomain in "${subdomains[@]}"; do
        create_dns_record "$subdomain.$DOMAIN" "CNAME" "$tunnel_id.cfargotunnel.com" true
    done
}

# Main menu
case "$1" in
    list)
        get_zone_id && list_dns_records
        ;;
    create)
        if [ $# -lt 4 ]; then
            echo "Usage: $0 create <name> <type> <content> [proxied]"
            echo "Example: $0 create test.$DOMAIN A 1.2.3.4 true"
            exit 1
        fi
        get_zone_id && create_dns_record "$2" "$3" "$4" "$5"
        ;;
    delete)
        if [ $# -lt 2 ]; then
            echo "Usage: $0 delete <record-id>"
            exit 1
        fi
        get_zone_id && delete_dns_record "$2"
        ;;
    setup-tunnel)
        get_zone_id && create_tunnel_records
        ;;
    check-config)
        echo -e "${BLUE}=== Configuration Check ===${NC}"
        if [ "$CLOUDFLARE_API_TOKEN" = "your-api-token-here" ]; then
            echo -e "${RED}❌ CLOUDFLARE_API_TOKEN not configured${NC}"
            echo "Get your API token from: https://dash.cloudflare.com/profile/api-tokens"
            echo "Create a token with DNS:Edit permissions for your zone"
        else
            echo -e "${GREEN}✅ CLOUDFLARE_API_TOKEN configured${NC}"
        fi

        if [ "$ZONE_ID" = "your-zone-id-here" ]; then
            echo -e "${YELLOW}⚠️  CLOUDFLARE_ZONE_ID not configured (will auto-detect)${NC}"
        else
            echo -e "${GREEN}✅ CLOUDFLARE_ZONE_ID configured${NC}"
        fi
        ;;
    *)
        echo "Cloudflare DNS Management Script"
        echo
        echo "Usage: $0 <command> [options]"
        echo
        echo "Commands:"
        echo "  check-config          Check API token and zone configuration"
        echo "  list                  List all DNS records"
        echo "  create <name> <type> <content> [proxied]  Create DNS record"
        echo "  delete <record-id>    Delete DNS record by ID"
        echo "  setup-tunnel          Create all tunnel CNAME records"
        echo
        echo "Examples:"
        echo "  $0 check-config"
        echo "  $0 list"
        echo "  $0 create argocd.$DOMAIN CNAME temitayocharles-tunnel.cfargotunnel.com true"
        echo "  $0 setup-tunnel"
        echo
        echo "Environment Variables:"
        echo "  CLOUDFLARE_API_TOKEN  Your Cloudflare API token"
        echo "  CLOUDFLARE_ZONE_ID    Your zone ID (optional, auto-detected)"
        ;;
esac
