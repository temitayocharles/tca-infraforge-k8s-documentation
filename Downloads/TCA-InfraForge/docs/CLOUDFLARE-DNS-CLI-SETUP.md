# Cloudflare DNS CLI Setup Guide

## Step 1: Get Your Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Choose "Create Custom Token"
4. Configure the token:
   - Name: "DNS Management CLI"
   - Permissions:
     - Zone: DNS: Edit
     - Zone: Zone: Read
   - Zone Resources: Include > Specific zone > temitayocharles.online
5. Click "Create Token"
6. Copy the token (you won't see it again!)

## Step 2: Get Your Zone ID

You can get this automatically with the script, or manually:
1. Go to https://dash.cloudflare.com/
2. Select your domain (temitayocharles.online)
3. Look at the URL: `https://dash.cloudflare.com/zone-id-here`
4. The zone ID is in the URL

## Step 3: Configure Environment Variables

Add these to your `~/.zshrc` or `~/.bash_profile`:

```bash
export CLOUDFLARE_API_TOKEN="your-actual-api-token-here"
export CLOUDFLARE_ZONE_ID="your-zone-id-here"  # Optional, auto-detected
```

Then reload your shell:
```bash
source ~/.zshrc
```

## Step 4: Test the Setup

```bash
./cloudflare-dns-cli.sh check-config
```

## Usage Examples

### Check Configuration
```bash
./cloudflare-dns-cli.sh check-config
```

### List All DNS Records
```bash
./cloudflare-dns-cli.sh list
```

### Create a DNS Record
```bash
# Create CNAME for ArgoCD
./cloudflare-dns-cli.sh create argocd.temitayocharles.online CNAME temitayocharles-tunnel.cfargotunnel.com true

# Create A record
./cloudflare-dns-cli.sh create test.temitayocharles.online A 1.2.3.4 false
```

### Setup All Tunnel Records
```bash
./cloudflare-dns-cli.sh setup-tunnel
```

### Delete a DNS Record
```bash
# First list records to get the ID
./cloudflare-dns-cli.sh list

# Then delete by ID
./cloudflare-dns-cli.sh delete 1234567890abcdef
```

## Script Features

- ✅ Automatic zone ID detection
- ✅ Batch tunnel record creation
- ✅ Error handling and validation
- ✅ Colored output for better readability
- ✅ Support for all DNS record types
- ✅ Proxied/unproxied record support

## Security Notes

- Keep your API token secure
- Use environment variables, not hardcoded values
- The token has limited permissions (DNS only)
- Rotate tokens regularly for security
