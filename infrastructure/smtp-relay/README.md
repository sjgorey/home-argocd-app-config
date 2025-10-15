# SMTP Relay Service

## Overview
Internal SMTP relay service for the K3s cluster. This service authenticates with the external SMTP server (mail.roadrunner.com) and provides an unauthenticated SMTP service within the cluster.

## Benefits
- **Centralized Authentication**: Only this service needs SMTP credentials
- **Simple Integration**: Other apps can send email without authentication
- **Security**: Credentials are managed in one place
- **Flexibility**: Easy to change external SMTP providers

## Deployment

**Prerequisites**: Create the SMTP credentials secret manually (see SECRET-SETUP.md):
```bash
kubectl create secret generic smtp-credentials \
  --from-literal=password='your-smtp-password' \
  -n smtp-relay
```

- **Namespace**: `smtp-relay` (dedicated namespace)
- **Service**: `smtp-relay.smtp-relay.svc.cluster.local`
- **Ports**: 
  - `25` (standard SMTP)
  - `587` (submission port)

## Usage for Other Applications

### From within the cluster:
```yaml
# In your application's environment variables:
- name: SMTP_HOST
  value: "smtp-relay.smtp-relay.svc.cluster.local"
- name: SMTP_PORT
  value: "25"
# No authentication required!
```

### From n8n:
In n8n email nodes, configure:
- **SMTP Host**: `smtp-relay.smtp-relay.svc.cluster.local`
- **Port**: `25`
- **Security**: `None` (internal cluster traffic)
- **Authentication**: `None`
- **From Address**: `gorco@maine.rr.com` (or any address allowed by roadrunner)

### Example Applications:
- n8n workflows
- AlertManager (✅ **Currently configured** to use this relay)
- Grafana notifications (ready to configure)
- Custom applications
- Backup scripts

## External SMTP Configuration
Currently configured to relay through:
- **Server**: `mail.roadrunner.com:587`
- **Username**: `gorco@maine.rr.com`
- **Authentication**: TLS with password

## Security
- Network policies restrict ingress to cluster traffic only
- Egress is limited to SMTP ports and DNS
- Credentials are stored in Kubernetes secrets
- Only accepts mail from cluster networks

## Monitoring
The service exposes standard Postfix logs for monitoring queue status and delivery.

## Troubleshooting

### Test connectivity:
```bash
# From within a cluster pod:
telnet smtp-relay.smtp-relay.svc.cluster.local 25

# Send test email:
kubectl run smtp-test --image=alpine --rm -it -- sh
apk add --no-cache mailx
echo "Test message" | mailx -S smtp=smtp-relay.smtp-relay.svc.cluster.local:25 \
  -s "Test Subject" -r "gorco@maine.rr.com" steve.gorey+test@gmail.com
```

### Check logs:
```bash
kubectl logs -n smtp-relay deployment/smtp-relay
```