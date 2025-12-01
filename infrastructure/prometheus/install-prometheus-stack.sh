#!/bin/bash
# Prometheus Stack Installation Script
# This script installs the complete Prometheus monitoring stack with proper ordering

set -e

echo "=== Prometheus Stack Installation ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_status "Connected to Kubernetes cluster"
echo ""

# Step 1: Install CRDs
echo "Step 1: Installing Prometheus Operator CRDs..."
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml 2>&1 | grep -v "Warning:" || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml 2>&1 | grep -v "Warning:" || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml 2>&1 | grep -v "Warning:" || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml 2>&1 | grep -v "Warning:" || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusagents.yaml 2>&1 | grep -v "Warning:" || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml 2>&1 | grep -v "Warning:" || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml 2>&1 | grep -v "Warning:" || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_scrapeconfigs.yaml 2>&1 | grep -v "Warning:" || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml 2>&1 | grep -v "Warning:" || true
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml 2>&1 | grep -v "Warning:" || true
print_status "CRDs installed successfully"
echo ""

# Step 2: Apply main Prometheus stack
echo "Step 2: Deploying Prometheus Stack..."
kubectl apply -f prometheus-stack.yaml 2>&1 | grep -E "(configured|created|unchanged)" | tail -20
print_status "Prometheus stack deployed"
echo ""

# Step 3: Apply additional monitors
echo "Step 3: Deploying additional service monitors..."
if [ -f "additional-monitors.yaml" ]; then
    kubectl apply -f additional-monitors.yaml
    print_status "Additional monitors deployed"
else
    print_warning "additional-monitors.yaml not found, skipping"
fi
echo ""

# Step 4: Apply ingresses
echo "Step 4: Configuring ingress routes..."
kubectl apply -f prometheus-ingress.yaml
kubectl apply -f grafana-ingress.yaml
if [ -f "alertmanager-ingress.yaml" ]; then
    kubectl apply -f alertmanager-ingress.yaml
fi
print_status "Ingress routes configured"
echo ""

# Step 5: Wait for pods to be ready
echo "Step 5: Waiting for pods to be ready..."
echo "This may take a few minutes..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s 2>/dev/null || print_warning "Grafana pod not ready yet"
kubectl wait --for=condition=ready pod -l app=kube-prometheus-stack-operator -n monitoring --timeout=300s 2>/dev/null || print_warning "Operator pod not ready yet"
print_status "Pods are starting up"
echo ""

# Step 6: Display status
echo "=== Installation Status ==="
echo ""
echo "Pods:"
kubectl get pods -n monitoring
echo ""
echo "Services:"
kubectl get svc -n monitoring
echo ""
echo "Ingresses:"
kubectl get ingress -n monitoring
echo ""
echo "Persistent Volume Claims:"
kubectl get pvc -n monitoring
echo ""

# Step 7: Display access information
echo "=== Access Information ==="
echo ""
print_status "Grafana: http://grafana.example.com"
echo "  Default credentials: admin / admin123"
echo ""
print_status "Prometheus: http://prometheus.example.com"
echo ""
print_status "AlertManager: http://alertmanager.example.com"
echo ""

print_warning "Remember to update domain names in ingress files if needed!"
print_warning "Change default Grafana password after first login!"
echo ""
print_status "Installation complete!"
