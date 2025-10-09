# Loki Stack for K3s with ArgoCD and Traefik

This directory contains a complete Loki log aggregation stack including Fluent Bit for log collection, integrated with your existing Prometheus/Grafana monitoring setup.

## Overview

This setup includes:
- **Loki** - Log aggregation system with label-based indexing
- **Fluent Bit** - Lightweight log processor and forwarder running as DaemonSet
- **Grafana Integration** - Automatic data source configuration for log visualization
- **Traefik Ingress** - Secure access to Loki API/UI with TLS

## Files Overview

- `loki-stack.yaml` - Main Loki and Fluent Bit manifests (generated from Helm chart)
- `loki-ingress.yaml` - Traefik ingress for Loki API access with basic auth
- `loki-tls-secret.yaml` - TLS certificate for HTTPS access
- `grafana-datasource.yaml` - ConfigMap to automatically add Loki as Grafana data source

## Prerequisites

- K3s cluster with Traefik ingress controller
- Longhorn storage for persistent volumes
- Existing Prometheus/Grafana monitoring stack
- ArgoCD for GitOps deployment

## Installation

### 1. Update Domain Names
```bash
# Update domains in ingress files
sed -i 's/loki.example.com/loki.yourdomain.com/g' loki-ingress.yaml
sed -i 's/loki.example.com/loki.yourdomain.com/g' loki-tls-secret.yaml
```

### 2. Update Passwords
```bash
# Generate new password hash for basic auth
htpasswd -nb admin your-new-password | base64 -w 0

# Update the secret in loki-ingress.yaml
```

### 3. Deploy via ArgoCD
```bash
# Apply the updated infrastructure configuration
kubectl apply -f ../../infrastructure.yaml

# Or apply manually for testing
kubectl apply -f loki-stack.yaml
kubectl apply -f loki-tls-secret.yaml
kubectl apply -f loki-ingress.yaml
kubectl apply -f grafana-datasource.yaml
```

### 4. Verify Installation
```bash
# Check logging namespace pods
kubectl get pods -n logging

# Check persistent volumes
kubectl get pvc -n logging

# Check Fluent Bit DaemonSet
kubectl get ds -n logging

# Check ingress
kubectl get ingress -n logging
```

## Access

### Loki API/UI
- **URL**: `https://loki.yourdomain.com`
- **Login**: `admin / loki123` (change this!)
- **Features**:
  - LogQL query interface
  - Label exploration
  - Metrics extraction from logs

### Via Grafana (Recommended)
- **URL**: Use your existing Grafana instance
- **Data Source**: Loki is automatically configured
- **Features**:
  - Unified metrics and logs view
  - Log correlation with metrics
  - Advanced dashboard creation

### Via Port Forward (Development)
```bash
kubectl port-forward -n logging svc/loki 3100:3100
# Access at: http://localhost:3100
```

## Log Collection

### What Gets Collected
Fluent Bit automatically collects:
- **Container logs** from all pods across all namespaces
- **Kubernetes metadata** (pod name, namespace, labels, annotations)
- **Node logs** from systemd services (kubelet, containerd, etc.)

### Log Labels
Logs are automatically labeled with:
- `namespace` - Kubernetes namespace
- `pod` - Pod name
- `container` - Container name
- `app` - Application label (if present)
- `node` - Node name
- `stream` - stdout/stderr

## Querying Logs

### Basic LogQL Examples
```logql
# All logs from a specific namespace
{namespace="default"}

# Logs from specific pod
{pod="my-pod-name"}

# Error logs across all containers
{container!=""} |= "error"

# Logs from last hour with filtering
{namespace="monitoring"} | json | level="error" [1h]
```

### Advanced Queries
```logql
# Rate of error logs per minute
rate({container!=""} |= "error" [1m])

# Top error-producing pods
topk(10, sum by (pod) (rate({container!=""} |= "error" [5m])))

# Log pattern detection
{namespace="default"} | pattern "<_> - <method> <path> <status> <_>"
```

## Configuration

### Storage
- **Loki**: 50GB Longhorn storage with configurable retention
- **Index**: In-memory with periodic flushing to storage
- **Chunks**: Stored in object storage format

### Retention Policy
Default retention settings:
- **Logs**: 30 days
- **Index**: 24 hours in memory, then persisted
- **Compaction**: Automatic background process

### Fluent Bit Configuration
- **Buffer**: 32MB per worker
- **Flush Interval**: 5 seconds
- **CPU Limit**: 100m per node
- **Memory Limit**: 128Mi per node

## Monitoring and Maintenance

### Health Checks
```bash
# Check Loki health
kubectl exec -n logging deployment/loki -- wget -qO- http://localhost:3100/ready

# Check Fluent Bit status
kubectl logs -n logging ds/loki-fluent-bit -f

# View Loki metrics
kubectl port-forward -n logging svc/loki 3100:3100
# Access: http://localhost:3100/metrics
```

### Troubleshooting

#### Common Issues

1. **Fluent Bit not collecting logs**: Check DaemonSet status and node permissions
2. **High memory usage**: Tune buffer settings in Fluent Bit configuration
3. **Slow queries**: Check label cardinality and add indexes if needed
4. **Storage issues**: Verify Longhorn volume mounting and space

#### Useful Commands
```bash
# Check Fluent Bit logs
kubectl logs -n logging ds/loki-fluent-bit --tail=100

# Check Loki logs
kubectl logs -n logging deployment/loki -f

# View current log ingestion rate
kubectl exec -n logging deployment/loki -- wget -qO- http://localhost:3100/loki/api/v1/label/__name__/values
```

## Integration with Grafana

### Automatic Setup
The Grafana data source is automatically configured via ConfigMap. After deployment:

1. **Restart Grafana** to pick up the new data source:
```bash
kubectl rollout restart deployment/kube-prometheus-stack-grafana -n monitoring
```

2. **Verify Data Source** in Grafana:
   - Go to Configuration → Data Sources
   - Look for "Loki" data source
   - Test connection

### Creating Log Dashboards
1. **Explore Logs**: Use Grafana's Explore feature with Loki data source
2. **Add Log Panels**: Add log panels to existing metric dashboards
3. **Correlate Data**: Link log queries with metric queries using variables

## Security Considerations

1. **Change default passwords** in ingress basic auth
2. **Use proper TLS certificates** for production
3. **Restrict ingress access** by IP if needed
4. **Monitor log volume** to prevent storage exhaustion
5. **Regular security updates** for Loki and Fluent Bit

## Customization

### Adding Custom Log Parsing
```yaml
# Add to Fluent Bit configmap
[FILTER]
    Name parser
    Match kube.*
    Key_Name log
    Parser my-custom-parser
```

### Custom Retention Policies
```yaml
# Update Loki configuration
limits_config:
  retention_period: 7d  # Keep logs for 7 days
  max_query_length: 12000h
```

### Additional Log Sources
```yaml
# Add new input to Fluent Bit for custom log files
[INPUT]
    Name tail
    Path /var/log/custom/*.log
    Tag custom.*
```

## Performance Tuning

### For Small Clusters (< 5 nodes)
- Default settings should be sufficient
- Monitor memory usage on Loki pod

### For Large Clusters (> 10 nodes)
- Increase Loki memory and storage
- Consider horizontal scaling with microservices mode
- Tune Fluent Bit buffer settings

### High Log Volume Environments
- Enable log sampling in Fluent Bit
- Implement log filtering to reduce noise
- Consider using Loki's query splitting

## Upgrading

To upgrade Loki:
1. Update the Helm chart version in generation command
2. Regenerate manifests: `helm template loki grafana/loki-stack ...`
3. Test in non-production environment
4. Commit and push to Git
5. ArgoCD will automatically apply the changes

## Support

- [Loki Documentation](https://grafana.com/docs/loki/)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Loki Integration](https://grafana.com/docs/grafana/latest/datasources/loki/)

## Example Queries for Your Environment

### Monitoring Kubernetes Components
```logql
# ArgoCD application sync logs
{namespace="argocd"} |= "sync"

# Longhorn storage events
{namespace="longhorn-system"} |= "volume"

# Prometheus scraping issues
{namespace="monitoring"} |= "scrape"

# Traefik routing logs
{app="traefik"} |= "router"
```

### Application Monitoring
```logql
# All application errors
{namespace!~"kube-.*|monitoring|longhorn-system|argocd"} |= "error"

# High-frequency log sources
topk(10, sum by (pod) (rate({container!=""}[5m])))

# Resource exhaustion indicators
{container!=""} |= "out of memory|disk full|connection refused"
```