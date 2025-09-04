#!/bin/bash

# TC Enterprise DevOps Platform™ - Image Source Mapping
# © 2025 Temitayo Charles. All Rights Reserved.
# Maps public registry images to TC Enterprise branded images

# Core mapping for secure pipeline
declare -A TC_IMAGE_MAPPING=(
    # Core Platform Services
    ["gitlab/gitlab-ce:16.3.0-ce.0"]="localhost:5001/tc-platform/gitlab:tc-v1.0-enterprise"
    ["goauthentik/server:2023.8.3"]="localhost:5001/tc-platform/authentik:tc-v1.0-enterprise"
    ["hashicorp/vault:1.15.0"]="localhost:5001/tc-platform/vault:tc-v1.0-enterprise"
    ["codercom/code-server:4.20.0"]="localhost:5001/tc-platform/vscode:tc-v1.0-enterprise"
    
    # Infrastructure Services
    ["redis:7-alpine"]="localhost:5001/tc-infrastructure/redis:tc-v1.0-enterprise"
    ["postgres:15-alpine"]="localhost:5001/tc-infrastructure/postgres:tc-v1.0-enterprise"
    ["minio/minio:RELEASE.2024-01-16T16-07-38Z"]="localhost:5001/tc-infrastructure/minio:tc-v1.0-enterprise"
    ["sonatype/nexus3:3.41.1"]="localhost:5001/tc-infrastructure/nexus:tc-v1.0-enterprise"
    ["rancher/k3s:v1.28.2-k3s1"]="localhost:5001/tc-infrastructure/k3s:tc-v1.0-enterprise"
    
    # Monitoring Stack
    ["prom/prometheus:v2.45.0"]="localhost:5001/tc-monitoring/prometheus:tc-v1.0-enterprise"
    ["grafana/grafana:10.0.0"]="localhost:5001/tc-monitoring/grafana:tc-v1.0-enterprise"
    ["jaegertracing/all-in-one:1.49"]="localhost:5001/tc-monitoring/jaeger:tc-v1.0-enterprise"
    ["grafana/loki:2.9.0"]="localhost:5001/tc-monitoring/loki:tc-v1.0-enterprise"
    ["grafana/promtail:2.9.0"]="localhost:5001/tc-monitoring/promtail:tc-v1.0-enterprise"
    ["prom/alertmanager:v0.26.0"]="localhost:5001/tc-monitoring/alertmanager:tc-v1.0-enterprise"
    
    # ML/AI Platform
    ["kubeflownotebookswg/jupyter-scipy:v1.7.0"]="localhost:5001/tc-ml/jupyter:tc-v1.0-enterprise"
    ["kubeflow/centraldashboard:v1.7.0"]="localhost:5001/tc-ml/kubeflow:tc-v1.0-enterprise"
    ["tensorflow/tensorflow:2.13.0"]="localhost:5001/tc-ml/tensorflow:tc-v1.0-enterprise"
    
    # Security Tools
    ["sonarqube:community"]="localhost:5001/tc-security/sonarqube:tc-v1.0-enterprise"
    ["aquasecurity/trivy-operator:0.16.0"]="localhost:5000/tc-security/trivy-operator:tc-v1.0-enterprise"
    ["ghcr.io/kyverno/kyverno:v1.10.0"]="localhost:5000/tc-security/kyverno:tc-v1.0-enterprise"
    
    # Service Mesh & Networking
    ["istio/pilot:1.18.0"]="localhost:5000/tc-mesh/istio-pilot:tc-v1.0-enterprise"
    ["istio/proxyv2:1.18.0"]="localhost:5000/tc-mesh/istio-proxy:tc-v1.0-enterprise"
    ["calico/node:v3.26.1"]="localhost:5000/tc-network/calico-node:tc-v1.0-enterprise"
    ["calico/cni:v3.26.1"]="localhost:5000/tc-network/calico-cni:tc-v1.0-enterprise"
    
    # Chaos Engineering & Workflows
    ["chaos-mesh/chaos-mesh:v2.5.1"]="localhost:5000/tc-chaos/chaos-mesh:tc-v1.0-enterprise"
    ["apache/airflow:2.7.0"]="localhost:5000/tc-workflow/airflow:tc-v1.0-enterprise"
    ["confluentinc/cp-kafka:7.4.0"]="localhost:5000/tc-streaming/kafka:tc-v1.0-enterprise"
    ["confluentinc/cp-zookeeper:7.4.0"]="localhost:5000/tc-streaming/zookeeper:tc-v1.0-enterprise"
)

# Export mapping for use by other scripts
export TC_IMAGE_MAPPING
