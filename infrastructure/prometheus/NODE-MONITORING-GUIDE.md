# K3s Node Monitoring and Alerting Setup

## Overview
This guide sets up comprehensive node monitoring and alerting for your K3s cluster using your existing Prometheus/Grafana stack.

## Components Added
1. **PrometheusRule** - 25+ alert rules for node health monitoring
2. **AlertManager Config** - Email, Slack, and webhook notifications
3. **Grafana Dashboard** - Real-time node health visualization
4. **Testing Tools** - Scripts to verify alerting works

## Alert Categories

### Critical Alerts (Immediate Response)
- **NodeDown** - Node completely unreachable (1min threshold)
- **NodeNotReady** - Node not ready in Kubernetes (2min threshold)
- **NodeCriticalCPUUsage** - CPU > 95% for 2 minutes
- **NodeCriticalMemoryUsage** - Memory > 95% for 2 minutes
- **NodeCriticalDiskUsage** - Disk > 90% for 2 minutes
- **KubeletDown** - Kubelet service down (1min threshold)

### Warning Alerts (Monitor and Plan)
- **NodeHighCPUUsage** - CPU > 80% for 5 minutes
- **NodeHighMemoryUsage** - Memory > 80% for 5 minutes  
- **NodeHighDiskUsage** - Disk > 80% for 5 minutes
- **NodeHighLoadAverage** - Load > 1.5x CPU count
- **NodeDiskWillFillIn4Hours** - Predictive disk fill alert

### Network and System Alerts
- **NodeNetworkInterfaceDown** - Network interface down
- **NodeNetworkHighErrors** - High network error rates
- **NodeClockSkew** - System clock drift > 60 seconds
- **NodeHighRestartRate** - Node restarts detected

## Deployment Instructions

### 1. Update Configuration
Before deploying, update these files with your specific details:

#### AlertManager Configuration (`alertmanager-config.yaml`)
```yaml
# Update email settings
smtp_smarthost: 'your-smtp-server:587'
smtp_from: 'alerts@yourdomain.com'
smtp_auth_username: 'your-username'
smtp_auth_password: 'your-app-password'

# Update Slack webhook
slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

# Update email recipients
to: 'admin@yourdomain.com,oncall@yourdomain.com'
```

#### Grafana Links
```yaml
# Update Grafana URL in alertmanager-config.yaml
url: 'https://grafana.yourdomain.com/d/k3s-node-health'
```

### 2. Deploy the Monitoring Stack
```bash
# Deploy alerting rules
kubectl apply -f k3s-node-alerts.yaml

# Deploy AlertManager configuration
kubectl apply -f alertmanager-config.yaml

# Deploy Grafana dashboard
kubectl apply -f grafana-k3s-dashboard.yaml

# Restart Grafana to pick up new dashboard
kubectl rollout restart deployment/kube-prometheus-stack-grafana -n monitoring
```

### 3. Verify Deployment
```bash
# Check PrometheusRule was created
kubectl get prometheusrule k3s-node-alerts -n monitoring

# Check AlertManager config
kubectl get secret alertmanager-config -n monitoring

# Check Grafana dashboard ConfigMap
kubectl get configmap k3s-node-health-dashboard -n monitoring

# Verify Prometheus picked up the rules
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Go to http://localhost:9090/rules and look for "k3s-node-health" group
```

## Testing the Alerting System

### Test 1: CPU Stress Test
```bash
# Create a CPU stress pod on a specific node
kubectl run cpu-stress --image=progrium/stress --rm -it --restart=Never -- --cpu 4 --timeout 600s

# Monitor alerts in Grafana or Prometheus
# Should trigger NodeHighCPUUsage after 5 minutes
```

### Test 2: Memory Stress Test  
```bash
# Create memory stress (adjust --vm-bytes based on node memory)
kubectl run memory-stress --image=progrium/stress --rm -it --restart=Never -- --vm 1 --vm-bytes 1G --timeout 300s

# Monitor for NodeHighMemoryUsage alert
```

### Test 3: Simulate Node Down
```bash
# Temporarily stop node-exporter on a node to simulate node down
kubectl patch daemonset node-exporter -n monitoring -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"nonexistent-node"}}}}}'

# Should trigger NodeDown alert after 1 minute
# Restore with:
kubectl patch daemonset node-exporter -n monitoring -p '{"spec":{"template":{"spec":{"nodeSelector":null}}}}'
```

## Accessing Monitoring

### Grafana Dashboard
1. Open Grafana: `https://grafana.yourdomain.com`
2. Go to **Dashboards** → **Browse** 
3. Look for **"K3s Node Health Dashboard"**
4. Pin to favorites for easy access

### Prometheus Alerts
1. Port-forward: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090`
2. Open: `http://localhost:9090/alerts`
3. View active alerts and their states

### AlertManager
1. Port-forward: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093`
2. Open: `http://localhost:9093`
3. View active alerts and silence/manage them

## Dashboard Features

The K3s Node Health Dashboard includes:

1. **Node Status Overview** - Quick status table showing UP/DOWN for all nodes
2. **CPU Usage per Node** - Real-time CPU utilization with 80%/95% thresholds
3. **Memory Usage per Node** - Memory utilization with alerts
4. **Disk Usage per Node** - Root filesystem usage monitoring
5. **Load Average** - System load per node
6. **Kubernetes Node Readiness** - K8s API perspective of node health
7. **Active Node Alerts** - Real-time alert status table

## Alert Routing Logic

### Critical Path (Immediate)
- **NodeDown** → Multiple channels (email + Slack + webhook)
- **Critical resource usage** → Email + critical Slack channel
- **Kubelet down** → Critical notifications

### Warning Path (Monitoring)
- **High resource usage** → Slack monitoring channel
- **Predictive alerts** → Planning notifications

### Inhibition Rules
- Critical alerts suppress related warning alerts
- Prevents alert storm during major incidents

## Notification Channels

### Email Notifications
- **Recipients**: Admin + on-call team
- **Frequency**: Immediate for critical, 30min for warnings
- **Content**: Full alert details + runbook links

### Slack Notifications  
- **#alerts-critical**: Critical alerts only
- **#monitoring**: All alerts and general monitoring
- **Features**: Color coding, @channel for emergencies

### Webhook Integration
- **Purpose**: Integration with external tools (PagerDuty, OpsGenie, etc.)
- **Format**: JSON webhook with full alert payload
- **Includes**: Resolved notifications

## Maintenance

### Regular Tasks
1. **Review alert thresholds** monthly based on cluster patterns
2. **Test notification channels** quarterly 
3. **Update contact information** as team changes
4. **Review and tune** alert frequency based on feedback

### Troubleshooting

#### Alerts Not Firing
```bash
# Check PrometheusRule syntax
kubectl describe prometheusrule k3s-node-alerts -n monitoring

# Check Prometheus logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-prometheus

# Verify metrics are available
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Query: up{job="node-exporter"}
```

#### Notifications Not Sending
```bash
# Check AlertManager logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-alertmanager

# Check AlertManager config
kubectl get secret alertmanager-config -n monitoring -o yaml

# Test SMTP connectivity from cluster
kubectl run email-test --image=busybox --rm -it --restart=Never -- nslookup your-smtp-server.com
```

## Security Considerations

1. **Email credentials**: Use app passwords, not main passwords
2. **Slack webhooks**: Rotate webhook URLs periodically  
3. **Access control**: Limit who can modify alert configurations
4. **Webhook security**: Use HTTPS and authentication for webhooks

## Next Steps

1. **Customize thresholds** based on your workload patterns
2. **Add application-specific alerts** using similar PrometheusRule patterns
3. **Integrate with ticketing systems** via webhooks
4. **Set up escalation policies** for unacknowledged critical alerts
5. **Create runbooks** for common alert scenarios