# Prometheus Monitoring Stack for K3s with ArgoCD and Traefik

This directory contains a complete Prometheus monitoring stack including Grafana, AlertManager, and various monitoring components for your K3s cluster.

## Overview

This setup includes:
- **Prometheus Server** - Metrics collection and storage
- **Grafana** - Visualization dashboards  
- **AlertManager** - Alert routing and management
- **Node Exporter** - Host metrics collection
- **kube-state-metrics** - Kubernetes resource metrics
- **Prometheus Operator** - CRD-based configuration management

## Files Overview

- `prometheus-stack.yaml` - Main kube-prometheus-stack Helm-generated manifests
- `prometheus-ingress.yaml` - Traefik ingress for Prometheus server access
- `grafana-ingress.yaml` - Traefik ingress for Grafana dashboard access  
- `tls-secrets.yaml` - TLS certificates for HTTPS access
- `additional-monitors.yaml` - Additional ServiceMonitors for comprehensive monitoring

## Configuration

### Storage
- **Prometheus**: 50GB Longhorn storage with 30-day retention
- **Grafana**: 10GB Longhorn storage for dashboard data
- **AlertManager**: 10GB Longhorn storage for alert data

### Access Credentials
- **Grafana**: 
  - Admin Username: `admin`
  - Admin Password: `admin123` (change this!)
  - Web Access: `https://grafana.example.com`
  - Ingress Auth: `admin / grafana123`

- **Prometheus**:
  - Web Access: `https://prometheus.example.com`  
  - Ingress Auth: `admin / prometheus123`

### Resource Limits
- **Prometheus**: 250m-1000m CPU, 1-2Gi RAM
- **Grafana**: 100m-500m CPU, 256Mi-512Mi RAM
- **AlertManager**: Default limits from chart

## Installation

### 1. Update Domain Names
```bash
# Update domains in ingress files
sed -i 's/grafana.example.com/grafana.yourdomain.com/g' grafana-ingress.yaml
sed -i 's/prometheus.example.com/prometheus.yourdomain.com/g' prometheus-ingress.yaml
sed -i 's/grafana.example.com/grafana.yourdomain.com/g' tls-secrets.yaml
sed -i 's/prometheus.example.com/prometheus.yourdomain.com/g' tls-secrets.yaml
```

### 2. Update Passwords
```bash
# Generate new password hashes
htpasswd -nb admin your-new-password | base64 -w 0

# Update the secrets in grafana-ingress.yaml and prometheus-ingress.yaml
```

### 3. Deploy via ArgoCD
```bash
# Apply the ArgoCD application (if not using infrastructure.yaml)
kubectl apply -f ../prometheus.yaml

# Or apply manually for testing
kubectl apply -f prometheus-stack.yaml
kubectl apply -f tls-secrets.yaml
kubectl apply -f grafana-ingress.yaml
kubectl apply -f prometheus-ingress.yaml
kubectl apply -f additional-monitors.yaml
```

### 4. Verify Installation
```bash
# Check monitoring namespace pods
kubectl get pods -n monitoring

# Check persistent volumes
kubectl get pvc -n monitoring

# Check ingress
kubectl get ingress -n monitoring
```

## Access

### Grafana Dashboard
- **URL**: `https://grafana.yourdomain.com`
- **Login**: `admin / admin123`
- **Features**:
  - Pre-configured Kubernetes dashboards
  - Prometheus data source configured
  - AlertManager integration

### Prometheus Server
- **URL**: `https://prometheus.yourdomain.com`  
- **Features**:
  - Query interface for metrics
  - Target discovery status
  - Alert rules management

### AlertManager
- **Access**: Via Grafana or port-forward
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Access at: http://localhost:9093
```

## Monitoring Targets

### Default Targets
- Kubernetes API Server
- kubelet metrics
- cAdvisor (container metrics)
- Node Exporter (host metrics)  
- kube-state-metrics
- CoreDNS
- Prometheus itself
- Grafana

### K3s Specific Targets
- K3s server components
- Traefik ingress controller
- Longhorn storage metrics
- etcd metrics (if available)

## Dashboard Examples

### Key Dashboards Available
1. **Kubernetes / Cluster** - Overall cluster health
2. **Kubernetes / Nodes** - Node resource usage
3. **Kubernetes / Pods** - Pod metrics and status
4. **Kubernetes / Deployments** - Deployment monitoring
5. **Traefik** - Ingress controller metrics
6. **Longhorn** - Storage system metrics

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check storage class and PVC creation
```bash
kubectl get pvc -n monitoring
kubectl describe pvc prometheus-kube-prometheus-stack-prometheus-db-0 -n monitoring
```

2. **Ingress not accessible**: Verify Traefik configuration and DNS
```bash
kubectl get ingress -n monitoring
kubectl describe ingress grafana-ingress -n monitoring
```

3. **No metrics appearing**: Check ServiceMonitor and target discovery
```bash
# Check Prometheus targets
# Access Prometheus UI -> Status -> Targets
```

### Useful Commands
```bash
# Check Prometheus operator logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-operator

# Check Grafana logs  
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana

# Port forward for local access
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

## Customization

### Adding Custom Dashboards
1. Import dashboards via Grafana UI
2. Or add ConfigMaps with dashboard JSON
3. Use Grafana's dashboard provisioning

### Adding Custom Alerts
1. Create PrometheusRule CRDs
2. Configure AlertManager routing
3. Set up notification channels (Slack, email, etc.)

### Monitoring Additional Services
1. Add ServiceMonitor CRDs
2. Ensure services have `/metrics` endpoints
3. Configure appropriate labels for discovery

## Security Considerations

1. **Change default passwords** in Grafana and ingress auth
2. **Use proper TLS certificates** for production
3. **Restrict ingress access** by IP if needed  
4. **Enable backup encryption** for sensitive metrics data
5. **Regular security updates** for monitoring components

## Architecture-Specific Notes

### Multi-Architecture Support
- Prometheus stack supports both AMD64 and ARM64
- Images are automatically selected based on node architecture
- Storage can be placed on specific architectures using nodeSelector

### Resource Planning
- **Small clusters** (3-5 nodes): Default settings sufficient
- **Large clusters** (10+ nodes): Increase storage and resources
- **High cardinality metrics**: Tune retention and storage accordingly

## Maintenance

### Backup Strategy
```bash
# Backup Grafana data
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- tar czf - /var/lib/grafana | gzip > grafana-backup.tar.gz

# Backup Prometheus data (snapshots)
# Use Prometheus admin API or storage-level snapshots
```

### Upgrade Process
1. Update Helm chart version in generation command
2. Test in non-production environment
3. Monitor during upgrade for data consistency
4. Validate all dashboards and alerts post-upgrade

## Support

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Operator](https://prometheus-operator.dev/)