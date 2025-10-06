# Kubernetes Dashboard

This directory contains the Kubernetes Dashboard deployment configuration for ArgoCD.

## Files

- `recommended.yaml` - Main Kubernetes Dashboard resources (from official manifests)
- `dashboard-ingress.yaml` - Traefik ingress configuration for external access
- `sa.yaml` - Admin user ServiceAccount and ClusterRoleBinding for full cluster access

## Setup

1. **Update the ingress host**: Edit `dashboard-ingress.yaml` and change `dashboard.local` to your actual domain
2. **TLS Certificate**: Ensure you have a TLS secret named `kubernetes-dashboard-tls-secret` in the `kubernetes-dashboard` namespace
3. **Deploy via ArgoCD**: The application is configured in `/apps/dashboard.yaml`

## Access

### Via Ingress
Access the dashboard at: `https://dashboard.local` (or your configured domain)

### Via Port Forward
```bash
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
```
Then access at: `https://localhost:8443`

## Authentication

Use the admin user token for full cluster access:

```bash
kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath="{.data.token}" | base64 -d
```

## Security Notes

- The admin-user has cluster-admin privileges - use with caution
- Consider creating more restrictive RBAC for production use
- The ingress is configured to skip certificate verification for the dashboard's self-signed certificates