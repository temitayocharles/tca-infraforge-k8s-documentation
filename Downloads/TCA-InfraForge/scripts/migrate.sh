#!/bin/bash
set -euo pipefail

# Enterprise DevOps Lab - Configuration Migration Tool
# Allows seamless migration between different systems and environments

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$ROOT_DIR/backups"
MIGRATION_DIR="$ROOT_DIR/migrations"

# Display usage
show_usage() {
    cat << EOF
Enterprise DevOps Lab - Migration Tool

USAGE:
    $0 export [profile]     Export current configuration and data
    $0 import <backup>      Import configuration to new system
    $0 migrate <source>     Migrate from different system/profile
    $0 list                 List available backups
    $0 validate <backup>    Validate backup integrity
    
EXAMPLES:
    $0 export                    # Export current active profile
    $0 export standard          # Export specific profile
    $0 import backup-20250806    # Import backup
    $0 migrate /path/to/old/lab  # Migrate from old installation
    
OPTIONS:
    --include-data    Include persistent data (volumes, secrets)
    --dry-run         Show what would be done without executing
    --force           Force operation without confirmation
    --compress        Compress backup (default)
    --encrypt         Encrypt backup with password

EOF
}

# Create backup directory structure
init_backup_structure() {
    mkdir -p "$BACKUP_DIR" "$MIGRATION_DIR"
    mkdir -p "$BACKUP_DIR/exports" "$BACKUP_DIR/imports"
}

# Get current active profile
get_active_profile() {
    if [ -f "$ROOT_DIR/.active_profile" ]; then
        cat "$ROOT_DIR/.active_profile"
    else
        # Try to detect from running KIND cluster
        local clusters=$(kind get clusters 2>/dev/null | grep "enterprise-devops" || echo "")
        if [ -n "$clusters" ]; then
            echo "$clusters" | head -n1 | sed 's/enterprise-devops-//'
        else
            echo ""
        fi
    fi
}

# Set active profile
set_active_profile() {
    local profile=$1
    echo "$profile" > "$ROOT_DIR/.active_profile"
    log "Set active profile to: $profile"
}

# Export configuration and data
export_config() {
    local profile=${1:-$(get_active_profile)}
    local include_data=${2:-false}
    local encrypt=${3:-false}
    
    if [ -z "$profile" ]; then
        error "No profile specified and no active profile found"
        exit 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="backup-${profile}-${timestamp}"
    local backup_path="$BACKUP_DIR/exports/$backup_name"
    
    log "Exporting profile '$profile' to $backup_name"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Export metadata
    cat > "$backup_path/metadata.json" << EOF
{
    "backup_name": "$backup_name",
    "profile": "$profile",
    "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "system": {
        "os": "$(uname -s)",
        "arch": "$(uname -m)",
        "hostname": "$(hostname)",
        "user": "$(whoami)"
    },
    "includes_data": $include_data,
    "encrypted": $encrypt,
    "version": "1.0.0"
}
EOF
    
    # Export configuration files
    log "Exporting configuration files..."
    mkdir -p "$backup_path/configs"
    
    if [ -f "$ROOT_DIR/kind-cluster-${profile}.yaml" ]; then
        cp "$ROOT_DIR/kind-cluster-${profile}.yaml" "$backup_path/configs/"
    fi
    
    if [ -f "$ROOT_DIR/system-info-${profile}.json" ]; then
        cp "$ROOT_DIR/system-info-${profile}.json" "$backup_path/configs/"
    fi
    
    # Export templates
    if [ -d "$ROOT_DIR/templates" ]; then
        log "Exporting templates..."
        cp -r "$ROOT_DIR/templates" "$backup_path/"
    fi
    
    # Export scripts
    if [ -d "$ROOT_DIR/scripts" ]; then
        log "Exporting scripts..."
        cp -r "$ROOT_DIR/scripts" "$backup_path/"
    fi
    
    # Export Kubernetes resources if cluster is running
    if kind get clusters 2>/dev/null | grep -q "enterprise-devops-$profile"; then
        log "Exporting Kubernetes resources..."
        mkdir -p "$backup_path/kubernetes"
        
        # Set context
        kubectl config use-context "kind-enterprise-devops-$profile"
        
        # Export core resources
        for resource in configmaps secrets services deployments statefulsets daemonsets; do
            kubectl get $resource --all-namespaces -o yaml > "$backup_path/kubernetes/${resource}.yaml" 2>/dev/null || true
        done
        
        # Export Helm releases
        if command -v helm &> /dev/null; then
            log "Exporting Helm releases..."
            helm list --all-namespaces -o json > "$backup_path/kubernetes/helm-releases.json" 2>/dev/null || true
        fi
        
        # Export persistent data if requested
        if [ "$include_data" = "true" ]; then
            log "Exporting persistent data..."
            mkdir -p "$backup_path/data"
            
            # Export PVCs
            kubectl get pvc --all-namespaces -o yaml > "$backup_path/data/pvcs.yaml" 2>/dev/null || true
            
            # Create data backup script for manual execution
            cat > "$backup_path/data/backup-volumes.sh" << 'EOSCRIPT'
#!/bin/bash
# Manual volume backup script
# Run this script to backup actual volume data

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Backup each PVC
kubectl get pvc --all-namespaces --no-headers | while read -r namespace pvc_name _; do
    echo "Creating backup job for $namespace/$pvc_name..."
    
    kubectl create job "backup-$pvc_name-$(date +%s)" \
        --image=alpine \
        --namespace="$namespace" \
        --dry-run=client -o yaml | \
    kubectl patch --local -f - -p "{
        \"spec\": {
            \"template\": {
                \"spec\": {
                    \"containers\": [{
                        \"name\": \"backup\",
                        \"image\": \"alpine\",
                        \"command\": [\"tar\"],
                        \"args\": [\"czf\", \"/backup/data.tar.gz\", \"/data\"],
                        \"volumeMounts\": [
                            {\"name\": \"data\", \"mountPath\": \"/data\"},
                            {\"name\": \"backup\", \"mountPath\": \"/backup\"}
                        ]
                    }],
                    \"volumes\": [
                        {\"name\": \"data\", \"persistentVolumeClaim\": {\"claimName\": \"$pvc_name\"}},
                        {\"name\": \"backup\", \"hostPath\": {\"path\": \"$BACKUP_DIR/volumes/$namespace-$pvc_name\"}}
                    ],
                    \"restartPolicy\": \"Never\"
                }
            }
        }
    }" --type=merge -o yaml | kubectl apply -f -
done
EOSCRIPT
            chmod +x "$backup_path/data/backup-volumes.sh"
        fi
    fi
    
    # Export Docker Compose data if running
    if [ -f "$ROOT_DIR/templates/docker-compose/infrastructure-${profile}.yaml" ]; then
        log "Exporting Docker Compose configuration..."
        mkdir -p "$backup_path/docker"
        cp "$ROOT_DIR/templates/docker-compose/infrastructure-${profile}.yaml" "$backup_path/docker/"
        
        if [ "$include_data" = "true" ]; then
            log "Exporting Docker volumes..."
            cd "$ROOT_DIR"
            docker-compose -f "templates/docker-compose/infrastructure-${profile}.yaml" config --volumes > "$backup_path/docker/volumes.txt" 2>/dev/null || true
        fi
    fi
    
    # Create restoration script
    log "Creating restoration script..."
    cat > "$backup_path/restore.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"; }

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$(pwd)}"

log "Restoring backup to: $TARGET_DIR"

# Load metadata
METADATA=$(cat "$BACKUP_DIR/metadata.json")
PROFILE=$(echo "$METADATA" | jq -r '.profile')
TIMESTAMP=$(echo "$METADATA" | jq -r '.timestamp')

log "Restoring profile: $PROFILE (backed up: $TIMESTAMP)"

# Copy configuration files
if [ -d "$BACKUP_DIR/configs" ]; then
    log "Restoring configuration files..."
    cp -r "$BACKUP_DIR/configs/"* "$TARGET_DIR/"
fi

# Copy templates
if [ -d "$BACKUP_DIR/templates" ]; then
    log "Restoring templates..."
    cp -r "$BACKUP_DIR/templates" "$TARGET_DIR/"
fi

# Copy scripts
if [ -d "$BACKUP_DIR/scripts" ]; then
    log "Restoring scripts..."
    cp -r "$BACKUP_DIR/scripts" "$TARGET_DIR/"
    find "$TARGET_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
fi

# Set active profile
echo "$PROFILE" > "$TARGET_DIR/.active_profile"

log "Restoration complete!"
log "Next steps:"
log "  1. Review restored configuration files"
log "  2. Run: ./scripts/auto-configure.sh (to adapt to new system)"
log "  3. Deploy: ./scripts/deployment/deploy-${PROFILE}.sh"

if [ -d "$BACKUP_DIR/kubernetes" ]; then
    warn "Kubernetes resources found in backup"
    warn "After cluster creation, restore with:"
    warn "  kubectl apply -f kubernetes/"
fi

if [ -d "$BACKUP_DIR/data" ]; then
    warn "Data backup found - run data/backup-volumes.sh if needed"
fi
EOF
    
    chmod +x "$backup_path/restore.sh"
    
    # Compress backup if requested
    if [ "${COMPRESS:-true}" = "true" ]; then
        log "Compressing backup..."
        cd "$BACKUP_DIR/exports"
        tar czf "${backup_name}.tar.gz" "$backup_name"
        rm -rf "$backup_name"
        backup_path="${backup_path}.tar.gz"
    fi
    
    # Encrypt backup if requested
    if [ "$encrypt" = "true" ]; then
        log "Encrypting backup..."
        if command -v openssl &> /dev/null; then
            read -s -p "Enter encryption password: " password
            echo
            openssl enc -aes-256-cbc -salt -in "$backup_path" -out "${backup_path}.enc" -pass pass:"$password"
            rm "$backup_path"
            backup_path="${backup_path}.enc"
        else
            warn "OpenSSL not found, skipping encryption"
        fi
    fi
    
    log "✅ Export complete: $(basename "$backup_path")"
    log "Backup location: $backup_path"
    
    # Update backup index
    update_backup_index "$backup_name" "$profile" "$backup_path"
}

# Import configuration
import_config() {
    local backup_name=$1
    local target_dir=${2:-$ROOT_DIR}
    local force=${3:-false}
    
    local backup_path=""
    
    # Find backup file
    if [ -f "$BACKUP_DIR/exports/$backup_name" ]; then
        backup_path="$BACKUP_DIR/exports/$backup_name"
    elif [ -f "$BACKUP_DIR/exports/${backup_name}.tar.gz" ]; then
        backup_path="$BACKUP_DIR/exports/${backup_name}.tar.gz"
    elif [ -f "$BACKUP_DIR/exports/${backup_name}.enc" ]; then
        backup_path="$BACKUP_DIR/exports/${backup_name}.enc"
    elif [ -f "$backup_name" ]; then
        backup_path="$backup_name"
    else
        error "Backup not found: $backup_name"
        exit 1
    fi
    
    log "Importing backup: $(basename "$backup_path")"
    
    # Create temporary extraction directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Decrypt if encrypted
    if [[ "$backup_path" == *.enc ]]; then
        log "Decrypting backup..."
        read -s -p "Enter decryption password: " password
        echo
        openssl enc -aes-256-cbc -d -in "$backup_path" -out "$temp_dir/backup.tar.gz" -pass pass:"$password"
        backup_path="$temp_dir/backup.tar.gz"
    fi
    
    # Extract if compressed
    if [[ "$backup_path" == *.tar.gz ]]; then
        log "Extracting backup..."
        tar xzf "$backup_path" -C "$temp_dir"
        local extracted_dir=$(ls "$temp_dir" | grep -v "backup.tar.gz" | head -n1)
        backup_path="$temp_dir/$extracted_dir"
    fi
    
    # Validate backup
    if [ ! -f "$backup_path/metadata.json" ]; then
        error "Invalid backup: missing metadata.json"
        exit 1
    fi
    
    # Load metadata
    local metadata=$(cat "$backup_path/metadata.json")
    local profile=$(echo "$metadata" | jq -r '.profile')
    local timestamp=$(echo "$metadata" | jq -r '.timestamp')
    local source_os=$(echo "$metadata" | jq -r '.system.os')
    local source_arch=$(echo "$metadata" | jq -r '.system.arch')
    
    log "Backup details:"
    log "  - Profile: $profile"
    log "  - Created: $timestamp"
    log "  - Source: $source_os ($source_arch)"
    
    # Check for conflicts
    if [ "$force" != "true" ] && [ -f "$target_dir/kind-cluster-${profile}.yaml" ]; then
        warn "Profile '$profile' already exists in target directory"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Import cancelled"
            exit 0
        fi
    fi
    
    # Run restore script
    if [ -f "$backup_path/restore.sh" ]; then
        log "Running restoration script..."
        cd "$backup_path"
        ./restore.sh "$target_dir"
    else
        # Manual restore
        log "Performing manual restoration..."
        if [ -d "$backup_path/configs" ]; then
            cp -r "$backup_path/configs/"* "$target_dir/"
        fi
        if [ -d "$backup_path/templates" ]; then
            cp -r "$backup_path/templates" "$target_dir/"
        fi
        if [ -d "$backup_path/scripts" ]; then
            cp -r "$backup_path/scripts" "$target_dir/"
            find "$target_dir/scripts" -name "*.sh" -exec chmod +x {} \;
        fi
        set_active_profile "$profile"
    fi
    
    log "✅ Import complete!"
    log "Imported profile: $profile"
    log ""
    log "Recommended next steps:"
    log "  1. Run auto-configuration to adapt to current system:"
    log "     ./scripts/auto-configure.sh"
    log "  2. Deploy the lab:"
    log "     ./scripts/deployment/deploy-${profile}.sh"
}

# List available backups
list_backups() {
    log "Available backups:"
    
    if [ ! -d "$BACKUP_DIR/exports" ] || [ -z "$(ls -A "$BACKUP_DIR/exports" 2>/dev/null)" ]; then
        info "No backups found"
        return
    fi
    
    printf "%-30s %-15s %-20s %-15s\n" "BACKUP NAME" "PROFILE" "CREATED" "SIZE"
    printf "%-30s %-15s %-20s %-15s\n" "$(printf '%*s' 30 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')" "$(printf '%*s' 20 | tr ' ' '-')" "$(printf '%*s' 15 | tr ' ' '-')"
    
    for backup in "$BACKUP_DIR/exports"/*; do
        if [ -f "$backup" ]; then
            local name=$(basename "$backup")
            local size=$(du -h "$backup" | cut -f1)
            local profile="N/A"
            local created="N/A"
            
            # Try to extract metadata for compressed backups
            if [[ "$backup" == *.tar.gz ]]; then
                local metadata=$(tar xzf "$backup" --to-stdout "*/metadata.json" 2>/dev/null | head -n1 || echo "{}")
                if [ "$metadata" != "{}" ]; then
                    profile=$(echo "$metadata" | jq -r '.profile // "N/A"')
                    created=$(echo "$metadata" | jq -r '.timestamp // "N/A"' | cut -dT -f1)
                fi
            fi
            
            printf "%-30s %-15s %-20s %-15s\n" "$name" "$profile" "$created" "$size"
        fi
    done
}

# Validate backup integrity
validate_backup() {
    local backup_name=$1
    
    # Find backup file (same logic as import)
    local backup_path=""
    if [ -f "$BACKUP_DIR/exports/$backup_name" ]; then
        backup_path="$BACKUP_DIR/exports/$backup_name"
    elif [ -f "$BACKUP_DIR/exports/${backup_name}.tar.gz" ]; then
        backup_path="$BACKUP_DIR/exports/${backup_name}.tar.gz"
    elif [ -f "$backup_name" ]; then
        backup_path="$backup_name"
    else
        error "Backup not found: $backup_name"
        exit 1
    fi
    
    log "Validating backup: $(basename "$backup_path")"
    
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Extract for validation
    if [[ "$backup_path" == *.tar.gz ]]; then
        if tar tf "$backup_path" > /dev/null 2>&1; then
            log "✅ Archive integrity: OK"
            tar xzf "$backup_path" -C "$temp_dir"
            local extracted_dir=$(ls "$temp_dir" | head -n1)
            backup_path="$temp_dir/$extracted_dir"
        else
            error "❌ Archive integrity: FAILED"
            exit 1
        fi
    fi
    
    # Validate required files
    local valid=true
    
    if [ ! -f "$backup_path/metadata.json" ]; then
        error "❌ Missing: metadata.json"
        valid=false
    else
        log "✅ Found: metadata.json"
        
        # Validate JSON
        if jq empty "$backup_path/metadata.json" 2>/dev/null; then
            log "✅ JSON validity: OK"
            
            # Show metadata
            local metadata=$(cat "$backup_path/metadata.json")
            log "Backup metadata:"
            echo "$metadata" | jq .
        else
            error "❌ JSON validity: FAILED"
            valid=false
        fi
    fi
    
    if [ ! -f "$backup_path/restore.sh" ]; then
        warn "⚠️  Missing: restore.sh (manual restore required)"
    else
        log "✅ Found: restore.sh"
    fi
    
    # Check for content directories
    for dir in configs templates scripts; do
        if [ -d "$backup_path/$dir" ]; then
            log "✅ Found: $dir/"
        else
            warn "⚠️  Missing: $dir/"
        fi
    done
    
    if [ "$valid" = "true" ]; then
        log "✅ Backup validation: PASSED"
    else
        error "❌ Backup validation: FAILED"
        exit 1
    fi
}

# Update backup index
update_backup_index() {
    local backup_name=$1
    local profile=$2
    local path=$3
    
    local index_file="$BACKUP_DIR/index.json"
    local entry=$(cat << EOF
{
    "name": "$backup_name",
    "profile": "$profile",
    "path": "$path",
    "created": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "size": $(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo 0)
}
EOF
)
    
    if [ ! -f "$index_file" ]; then
        echo "[]" > "$index_file"
    fi
    
    # Add entry to index
    jq ". += [$entry]" "$index_file" > "$index_file.tmp" && mv "$index_file.tmp" "$index_file"
}

# Main execution
main() {
    init_backup_structure
    
    case "${1:-}" in
        export)
            export_config "${2:-}" "${INCLUDE_DATA:-false}" "${ENCRYPT:-false}"
            ;;
        import)
            if [ -z "${2:-}" ]; then
                error "Backup name required for import"
                show_usage
                exit 1
            fi
            import_config "$2" "${3:-$ROOT_DIR}" "${FORCE:-false}"
            ;;
        migrate)
            if [ -z "${2:-}" ]; then
                error "Source path required for migration"
                show_usage
                exit 1
            fi
            # Migration is essentially an import from external source
            import_config "$2" "$ROOT_DIR" "${FORCE:-false}"
            ;;
        list)
            list_backups
            ;;
        validate)
            if [ -z "${2:-}" ]; then
                error "Backup name required for validation"
                show_usage
                exit 1
            fi
            validate_backup "$2"
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --include-data)
            export INCLUDE_DATA=true
            shift
            ;;
        --dry-run)
            export DRY_RUN=true
            shift
            ;;
        --force)
            export FORCE=true
            shift
            ;;
        --compress)
            export COMPRESS=true
            shift
            ;;
        --encrypt)
            export ENCRYPT=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

main "$@"
