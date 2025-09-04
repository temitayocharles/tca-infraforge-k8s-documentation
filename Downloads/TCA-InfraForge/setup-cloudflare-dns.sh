#!/bin/bash

# Quick Cloudflare DNS Setup Script

echo "=== Cloudflare DNS CLI Quick Setup ==="
echo

# Check if jq is installed (needed for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "Installing jq (required for JSON parsing)..."
    brew install jq
fi

echo "Enter your Cloudflare API Token:"
echo "(Get it from: https://dash.cloudflare.com/profile/api-tokens)"
read -s CLOUDFLARE_API_TOKEN

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ No API token provided. Exiting."
    exit 1
fi

echo
echo "Testing API token..."

# Test the API token
response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json")

success=$(echo "$response" | jq -r '.success' 2>/dev/null)

if [ "$success" = "true" ]; then
    echo "✅ API token is valid!"

    # Add to shell profile
    shell_profile="$HOME/.zshrc"
    if [ -f "$HOME/.bash_profile" ]; then
        shell_profile="$HOME/.bash_profile"
    fi

    echo "Adding to $shell_profile..."
    echo "export CLOUDFLARE_API_TOKEN=\"$CLOUDFLARE_API_TOKEN\"" >> "$shell_profile"

    # Reload shell
    source "$shell_profile"

    echo
    echo "✅ Setup complete! You can now use:"
    echo "  ./cloudflare-dns-cli.sh check-config"
    echo "  ./cloudflare-dns-cli.sh list"
    echo "  ./cloudflare-dns-cli.sh setup-tunnel"
    echo
    echo "To apply changes, restart your terminal or run: source $shell_profile"

else
    echo "❌ Invalid API token. Please check and try again."
    echo "Response: $response"
    exit 1
fi
