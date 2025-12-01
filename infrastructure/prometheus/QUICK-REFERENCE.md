# Prometheus Stack Quick Reference

## Installation Order

1. **CRDs** - Must be installed first
2. **Prometheus Stack** - Main deployment
3. **Ingress Routes** - External access
4. **Additional Monitors** - Optional monitoring extensions

## Quick Commands

### Fresh Installation
```bash
# Automated (recommended)
./install-prometheus-stack.sh

# Manual
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.86.0/example/prometheus-operator-crd/*.yaml
kubectl apply -f prometheus-stack.yaml
kubectl apply -f *-ingress.yaml
kubectl apply -f additional-monitors.yaml
```

### Check Status
```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get ingress -n monitoring
kubectl get pvc -n monitoring
kubectl get prometheus,alertmanager -n monitoring
```

### Access URLs
- Grafana: http://grafana.example.com (admin/admin123)
- Prometheus: http://prometheus.example.com
- AlertManager: http://alertmanager.example.com

### Troubleshooting
```bash
# Check operator logs
kubectl logs -n monitoring -l app=kube-prometheus-stack-operator --tail=50

# Check Prometheus logs
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus

# Check if CRDs are installed
kubectl get crd | grep monitoring.coreos.com

# Check Prometheus custom resource
kubectl get prometheus -n monitoring

# Restart operator if CRDs were just installed
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-operator
```

### Cleanup
```bash
# Delete everything
kubectl delete -f additional-monitors.yaml
kubectl delete -f *-ingress.yaml
kubectl delete -f prometheus-stack.yaml

# Delete CRDs (this will remove all Prometheus resources!)
kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd probes.monitoring.coreos.com
kubectl delete crd prometheusagents.monitoring.coreos.com
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd scrapeconfigs.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com
```

## Key Differences from Standard Setup

- **No TLS** - All services use HTTP
- **No Basic Auth** - No ingress authentication
- **Prometheus Operator Port** - Changed from 10250 (HTTPS) to 8080 (HTTP)
- **Private Network Only** - Not suitable for public internet exposure

## Files Not Used
- `tls-secrets.yaml` - TLS is disabled, this file is not applied
