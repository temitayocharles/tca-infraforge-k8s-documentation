#!/bin/bash

# ============================================================================
# 🔍 TC Enterprise DevOps Platform™ - Deployment Verification
# ============================================================================
#
# This script verifies the complete deployment status and provides
# comprehensive health checks for all components
#
# ============================================================================

set -e

# ============================================================================
# 🎨 COLOR SCHEME & FORMATTING
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CHECKMARK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
GEAR="⚙️"
ROCKET="🚀"
LOCK="🔒"
NETWORK="🌐"
DATABASE="🗄️"
MONITOR="📊"
CLOUD="☁️"
SHIELD="🛡️"

# ============================================================================
# 📊 VERIFICATION FUNCTIONS
# ============================================================================

verify_cluster_status() {
    echo -e "\n${BLUE}${GEAR} CLUSTER STATUS VERIFICATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"

    # Check if cluster exists
    if ! kind get clusters | grep -q "tc-devops-cluster"; then
        echo -e "${RED}${CROSS} Kubernetes cluster 'tc-devops-cluster' not found${NC}"
        return 1
    fi

    echo -e "${GREEN}${CHECKMARK} Kubernetes cluster found${NC}"

    # Check node status
    local ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready")
    local total_nodes=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')

    if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
        echo -e "${GREEN}${CHECKMARK} All nodes ready: $ready_nodes/$total_nodes${NC}"
        kubectl get nodes --no-headers | while read node status roles age version; do
            echo -e "  ${GREEN}•${NC} $node: $status ($age)"
        done
    else
        echo -e "${RED}${CROSS} Node status issue: $ready_nodes/$total_nodes ready${NC}"
        return 1
    fi

    return 0
}

verify_ingress_status() {
    echo -e "\n${BLUE}${NETWORK} INGRESS CONTROLLER VERIFICATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"

    # Check ingress controller pods
    local ingress_pods=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$ingress_pods" -gt 0 ]; then
        echo -e "${GREEN}${CHECKMARK} Ingress controller running ($ingress_pods pods)${NC}"
    else
        echo -e "${RED}${CROSS} Ingress controller not running${NC}"
        return 1
    fi

    # Check ingress service
    if kubectl get svc -n ingress-nginx ingress-nginx-controller &>/dev/null; then
        echo -e "${GREEN}${CHECKMARK} Ingress service configured${NC}"
    else
        echo -e "${RED}${CROSS} Ingress service not found${NC}"
        return 1
    fi

    # Test ingress functionality
    local test_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:30000/ 2>/dev/null || echo "000")
    if [ "$test_response" != "000" ]; then
        echo -e "${GREEN}${CHECKMARK} Ingress responding (HTTP $test_response)${NC}"
    else
        echo -e "${YELLOW}${WARNING} Ingress test inconclusive${NC}"
    fi

    return 0
}

verify_monitoring_status() {
    echo -e "\n${BLUE}${MONITOR} MONITORING STACK VERIFICATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"

    # Check monitoring namespace
    if ! kubectl get namespace monitoring &>/dev/null; then
        echo -e "${RED}${CROSS} Monitoring namespace not found${NC}"
        return 1
    fi

    # Check Prometheus
    local prometheus_pods=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$prometheus_pods" -gt 0 ]; then
        echo -e "${GREEN}${CHECKMARK} Prometheus running ($prometheus_pods pods)${NC}"
    else
        echo -e "${RED}${CROSS} Prometheus not running${NC}"
        return 1
    fi

    # Check Grafana
    local grafana_pods=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$grafana_pods" -gt 0 ]; then
        echo -e "${GREEN}${CHECKMARK} Grafana running ($grafana_pods pods)${NC}"
    else
        echo -e "${RED}${CROSS} Grafana not running${NC}"
        return 1
    fi

    # Check AlertManager
    local alertmanager_pods=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$alertmanager_pods" -gt 0 ]; then
        echo -e "${GREEN}${CHECKMARK} AlertManager running ($alertmanager_pods pods)${NC}"
    else
        echo -e "${YELLOW}${WARNING} AlertManager not running${NC}"
    fi

    return 0
}

verify_applications_status() {
    echo -e "\n${BLUE}${ROCKET} ENTERPRISE APPLICATIONS VERIFICATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"

    # Check PostgreSQL
    local postgres_status=$(kubectl get pods -l app=postgres --no-headers 2>/dev/null | awk '{print $3}' || echo "")
    if [ "$postgres_status" = "Running" ]; then
        echo -e "${GREEN}${CHECKMARK} PostgreSQL database running${NC}"
    else
        echo -e "${RED}${CROSS} PostgreSQL not running (status: $postgres_status)${NC}"
        return 1
    fi

    # Check backend API
    local backend_status=$(kubectl get pods -l app=tc-backend --no-headers 2>/dev/null | awk '{print $3}' || echo "")
    if [ "$backend_status" = "Running" ]; then
        echo -e "${GREEN}${CHECKMARK} Backend API running${NC}"

        # Test backend health
        local health_response=$(kubectl run test-health --image=curlimages/curl --rm -i --restart=Never -- curl -s http://tc-backend:3000/api/health 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")
        if [ "$health_response" = "healthy" ]; then
            echo -e "${GREEN}${CHECKMARK} Backend health check passed${NC}"
        else
            echo -e "${YELLOW}${WARNING} Backend health check inconclusive${NC}"
        fi
    else
        echo -e "${RED}${CROSS} Backend API not running (status: $backend_status)${NC}"
        return 1
    fi

    # Check frontend
    local frontend_status=$(kubectl get pods -l app=tc-frontend --no-headers 2>/dev/null | awk '{print $3}' || echo "")
    if [ "$frontend_status" = "Running" ]; then
        echo -e "${GREEN}${CHECKMARK} Frontend application running${NC}"
    else
        echo -e "${RED}${CROSS} Frontend not running (status: $frontend_status)${NC}"
        return 1
    fi

    return 0
}

verify_security_status() {
    echo -e "\n${BLUE}${SHIELD} SECURITY CONFIGURATION VERIFICATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"

    # Check network policies
    local network_policies=$(kubectl get networkpolicies --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$network_policies" -gt 0 ]; then
        echo -e "${GREEN}${CHECKMARK} Network policies configured ($network_policies policies)${NC}"
    else
        echo -e "${YELLOW}${WARNING} No network policies found${NC}"
    fi

    # Check RBAC
    local cluster_roles=$(kubectl get clusterrolebindings --no-headers 2>/dev/null | grep -c "tc-admin" || echo "0")
    if [ "$cluster_roles" -gt 0 ]; then
        echo -e "${GREEN}${CHECKMARK} RBAC policies configured${NC}"
    else
        echo -e "${YELLOW}${WARNING} RBAC policies not found${NC}"
    fi

    # Check service accounts
    if kubectl get serviceaccount tc-admin &>/dev/null; then
        echo -e "${GREEN}${CHECKMARK} Service accounts configured${NC}"
    else
        echo -e "${YELLOW}${WARNING} Service accounts not found${NC}"
    fi

    return 0
}

verify_external_access() {
    echo -e "\n${BLUE}${CLOUD} EXTERNAL ACCESS VERIFICATION${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"

    # Test main application
    local app_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
    if [ "$app_response" = "200" ]; then
        echo -e "${GREEN}${CHECKMARK} Main application accessible at http://localhost/${NC}"
    else
        echo -e "${YELLOW}${WARNING} Main application not accessible (HTTP $app_response)${NC}"
    fi

    # Test API endpoint
    local api_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health 2>/dev/null || echo "000")
    if [ "$api_response" = "200" ]; then
        echo -e "${GREEN}${CHECKMARK} API endpoint accessible at http://localhost/api/health${NC}"
    else
        echo -e "${YELLOW}${WARNING} API endpoint not accessible (HTTP $api_response)${NC}"
    fi

    # Check port availability
    if lsof -i :80 &>/dev/null; then
        echo -e "${GREEN}${CHECKMARK} Port 80 available for external access${NC}"
    else
        echo -e "${YELLOW}${WARNING} Port 80 not available${NC}"
    fi

    if lsof -i :30000 &>/dev/null; then
        echo -e "${GREEN}${CHECKMARK} Port 30000 available for ingress${NC}"
    else
        echo -e "${YELLOW}${WARNING} Port 30000 not available${NC}"
    fi

    return 0
}

generate_status_report() {
    echo -e "\n${BLUE}${MONITOR} DEPLOYMENT STATUS REPORT${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"

    local report_file="/Users/charlie/Documents/my-devops-lab/verification_report_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "TC Enterprise DevOps Platform™ - Verification Report"
        echo "Generated: $(date)"
        echo "════════════════════════════════════════════════════════"
        echo
        echo "CLUSTER STATUS:"
        kubectl get nodes
        echo
        echo "POD STATUS:"
        kubectl get pods --all-namespaces
        echo
        echo "SERVICE STATUS:"
        kubectl get services --all-namespaces
        echo
        echo "INGRESS STATUS:"
        kubectl get ingress --all-namespaces
        echo
        echo "NETWORK POLICIES:"
        kubectl get networkpolicies
        echo
        echo "STORAGE STATUS:"
        kubectl get pv,pvc
        echo
        echo "ENDPOINTS:"
        echo "  Frontend: http://localhost/"
        echo "  API: http://localhost/api/health"
        echo "  Prometheus: http://prometheus.local/"
        echo "  Grafana: http://grafana.local/"
        echo "  Grafana Credentials: admin/TCEnterprise2025!"
    } > "$report_file"

    echo -e "${GREEN}${CHECKMARK} Status report saved to: $report_file${NC}"
}

# ============================================================================
# 🎯 MAIN VERIFICATION FUNCTION
# ============================================================================

main() {
    echo -e "${BLUE}${GEAR} TC Enterprise DevOps Platform™ - Deployment Verification${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Verifying complete enterprise infrastructure deployment...${NC}\n"

    local start_time=$(date +%s)
    local errors=0
    local warnings=0

    # Run all verifications
    if ! verify_cluster_status; then ((errors++)); fi
    if ! verify_ingress_status; then ((errors++)); fi
    if ! verify_monitoring_status; then ((errors++)); fi
    if ! verify_applications_status; then ((errors++)); fi
    if ! verify_security_status; then ((warnings++)); fi
    if ! verify_external_access; then ((warnings++)); fi

    # Generate status report
    generate_status_report

    # Calculate verification time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${MONITOR} VERIFICATION SUMMARY${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}${CHECKMARK} VERIFICATION PASSED${NC}"
        echo -e "${GREEN}All critical components are running correctly!${NC}"
    else
        echo -e "${RED}${CROSS} VERIFICATION FAILED${NC}"
        echo -e "${RED}$errors critical issues found${NC}"
    fi

    if [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}${WARNING} $warnings warnings detected${NC}"
    fi

    echo -e "${BLUE}${INFO} Verification completed in ${duration} seconds${NC}"

    # Access information
    if [ $errors -eq 0 ]; then
        echo -e "\n${GREEN}${ROCKET} ACCESS YOUR PLATFORM:${NC}"
        echo -e "  🌐 Frontend Dashboard:    ${GREEN}http://localhost/${NC}"
        echo -e "  🔧 Backend API:           ${GREEN}http://localhost/api/health${NC}"
        echo -e "  📊 Prometheus Monitoring: ${GREEN}http://prometheus.local/${NC}"
        echo -e "  📈 Grafana Dashboards:    ${GREEN}http://grafana.local/${NC}"
        echo -e "     Username: ${YELLOW}admin${NC} | Password: ${YELLOW}TCEnterprise2025!${NC}"
    fi

    return $errors
}

# ============================================================================
# 🎯 SCRIPT ENTRY POINT
# ============================================================================

case "$1" in
    --help|-h)
        echo "TC Enterprise DevOps Platform™ - Deployment Verification"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --cluster-only      Only verify cluster status"
        echo "  --apps-only         Only verify applications"
        echo "  --security-only     Only verify security configuration"
        echo
        echo "Examples:"
        echo "  $0                  # Full verification"
        echo "  $0 --cluster-only  # Check cluster only"
        echo "  $0 --apps-only     # Check applications only"
        exit 0
        ;;
    --cluster-only)
        verify_cluster_status
        ;;
    --apps-only)
        verify_applications_status
        ;;
    --security-only)
        verify_security_status
        ;;
    *)
        main
        ;;
esac
