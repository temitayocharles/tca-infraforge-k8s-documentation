# Apple Silicon Integration Guide

## Overview
The TC Enterprise DevOps Platform now includes intelligent Apple Silicon detection and automatic VM integration for enterprise-grade Kubernetes clusters.

## How It Works

### 1. **Intelligent Detection**
- Automatically detects Apple Silicon (arm64) hardware
- Identifies Docker Desktop limitations for multi-node clusters
- Triggers VM fallback only when necessary

### 2. **Seamless VM Integration**
- **Colima VM**: Lightweight Linux VM for native Kubernetes support
- **Automatic Setup**: Installs, configures, and optimizes VM resources
- **Context Switching**: Seamlessly switches Docker/Kubernetes contexts

### 3. **Enterprise-Grade Deployment**
Once in VM environment:
- **3-node cluster**: 1 control plane + 2 specialized workers
- **Production simulation**: Real enterprise networking and security
- **Advanced features**: All kubeadm patches and enterprise configs work

## Architecture

```
┌─────────────────────────────────────────────┐
│ macOS (Apple Silicon)                       │
│ ┌─────────────────────────────────────────┐ │
│ │ Colima Linux VM                         │ │
│ │ ┌─────────────────────────────────────┐ │ │
│ │ │ KIND Kubernetes Cluster             │ │ │
│ │ │ ├── Control Plane                   │ │ │
│ │ │ ├── Worker 1 (Compute)             │ │ │
│ │ │ └── Worker 2 (Storage/DB)          │ │ │
│ │ └─────────────────────────────────────┘ │ │
│ │ Docker + containerd (native Linux)     │ │
│ └─────────────────────────────────────────┘ │
│ Host: macOS with full access               │
└─────────────────────────────────────────────┘
```

## Automatic Behavior

### Default Flow (Intel/Windows/Linux)
1. Try native Docker/KIND cluster creation
2. Use sophisticated enterprise configurations
3. Deploy successfully without VM

### Apple Silicon Flow  
1. Try native Docker/KIND cluster creation
2. **If kubelet fails** → Detect Apple Silicon
3. **Auto-install Colima** → Update system packages
4. **Start Linux VM** → Allocate optimal resources
5. **Switch contexts** → Use VM for all operations
6. **Deploy enterprise cluster** → Full 3-node production simulation

## Resource Allocation

**VM Resources (Auto-calculated):**
- **CPU**: Host cores - 1 (minimum 2)
- **Memory**: Host RAM - 2GB (minimum 4GB)  
- **Disk**: 60GB (sufficient for enterprise workloads)

**Example on 8GB/8-core Mac:**
- VM: 6GB RAM, 7 CPUs
- Host: 2GB RAM, 1 CPU (for macOS)

## Benefits

### Performance
- **Native Linux performance** inside VM
- **No emulation overhead** for containers
- **Full cgroup/systemd support**

### Compatibility  
- **All Kubernetes features** work correctly
- **Multi-node clusters** without limitations
- **Enterprise security** and networking

### Transparency
- **No user intervention** required
- **Seamless experience** - "just works"
- **Automatic fallback** and recovery

## Troubleshooting

### VM Issues
```bash
# Check Colima status
colima status

# Restart if needed
colima stop && colima start --cpu 4 --memory 8 --kubernetes

# Switch contexts manually
docker context use colima
kubectl config use-context colima
```

### Context Issues
```bash
# Verify current context
docker context show
kubectl config current-context

# Should show "colima" on Apple Silicon after setup
```

## Files Modified

- `enterprise-lab-orchestrator.sh`: Added intelligent detection and VM integration
- `kind-cluster-standard.yaml`: Enhanced for true enterprise simulation in VM
- Added functions: `is_apple_silicon()`, `needs_vm_fallback()`, `install_and_setup_colima()`

## Supported Platforms

| Platform | Method | Multi-node | Enterprise Features |
|----------|--------|------------|-------------------|
| Intel Mac | Native KIND | ✅ | ✅ |
| Apple Silicon | Colima VM | ✅ | ✅ |
| Linux | Native KIND | ✅ | ✅ |
| Windows | Native KIND | ✅ | ✅ |

This ensures **consistent enterprise-grade experience** across all platforms while optimizing for each platform's capabilities.
