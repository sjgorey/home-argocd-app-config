# AlertManager SMTP Email Configuration

## Overview
This directory contains the AlertManager configuration for sending email notifications from the K3s cluster monitoring setup.

## Files

### `alertmanager-config-simple.yaml`
**Status: ✅ PRODUCTION - Currently Active**
- Working AlertmanagerConfig v1alpha1 resource
- SMTP server: `mail.roadrunner.com:587` with TLS
- Uses `smtp-auth` secret for password management
- Routes infrastructure alerts to `gorco@maine.rr.com`

### `alertmanager-config.yaml` 
**Status: ⚠️ LEGACY - Secret-based configuration**
- Original Secret-based configuration (deprecated approach)
- Not used by kube-prometheus-stack AlertManager
- Kept for reference only

## SMTP Configuration Details

### Prerequisites
1. **SMTP Secret**: Create the password secret:
   ```bash
   kubectl create secret generic smtp-auth \
     --from-literal=password='your-email-password' \
     -n monitoring
   ```

2. **SMTP Server Access**: Verify connectivity:
   ```bash
   swaks --to gorco@maine.rr.com \
     --from gorco@maine.rr.com \
     --auth-user gorco@maine.rr.com \
     --auth-password 'your-password' \
     --server mail.roadrunner.com:587 \
     --tls
   ```

### Current Active Alerts
The system sends emails for these K3s infrastructure alerts:
- **NodeDown**: Node completely unavailable
- **NodeNotReady**: Node not ready in Kubernetes  
- **NodeHighCPUUsage**: CPU usage > 80%
- **NodeCriticalCPUUsage**: CPU usage > 95%
- **NodeHighMemoryUsage**: Memory usage > 80%
- **NodeCriticalMemoryUsage**: Memory usage > 95%
- **NodeHighDiskUsage**: Disk usage > 80%
- **NodeCriticalDiskUsage**: Disk usage > 95%
- **NodeNetworkInterfaceDown**: Network interfaces down
- **NodeTooManyPods**: Pod capacity approaching limits
- Plus many more node health alerts

## Usage

### Apply Configuration
```bash
kubectl apply -f alertmanager-config-simple.yaml
```

### Verify Configuration
```bash
# Check AlertmanagerConfig status
kubectl get alertmanagerconfig -n monitoring

# Check AlertManager logs for SMTP activity
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 | grep -i smtp

# Test with a temporary alert
kubectl apply -f debug/test-alert.yaml
```

### View Alerts in AlertManager UI
Access via Grafana > Explore > AlertManager datasource or direct port-forward:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Open http://localhost:9093
```

## Troubleshooting

### Common Issues
1. **TLS Certificate Errors**: Ensure using correct hostname (`mail.roadrunner.com` not `smtp-server.maine.rr.com`)
2. **Authentication Failures**: Verify smtp-auth secret exists and has correct password
3. **No Emails**: Check AlertManager logs and verify Prometheus is sending alerts to AlertManager

### Useful Commands
```bash
# Check firing alerts in Prometheus
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state == "firing")'

# Check alerts in AlertManager  
curl -s http://localhost:9093/api/v2/alerts | jq '.[0]'

# Restart AlertManager to reload config
kubectl delete pod alertmanager-kube-prometheus-stack-alertmanager-0 -n monitoring
```

## Security Notes
- Passwords are stored in Kubernetes secrets, not in YAML files
- TLS encryption is enabled for SMTP connections
- Email addresses and SMTP server details are in GitOps configuration for transparency