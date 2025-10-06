# Kubernetes Dashboard (Insecure Mode)

This directory contains the Kubernetes Dashboard deployment configuration for ArgoCD, running in **insecure mode** (HTTP) with TLS termination at the ingress level.

## Files

- `recommended.yaml` - Main Kubernetes Dashboard resources (configured for HTTP/insecure mode)
- `dashboard-ingress.yaml` - Traefik ingress configuration for external HTTPS access
- `sa.yaml` - Admin user ServiceAccount and ClusterRoleBinding for full cluster access
- `tls-secret.yaml` - TLS certificate secret for HTTPS access at ingress level
- `certificate-optional.yaml` - Alternative cert-manager configuration (if available)
- `enhanced-rbac-optional.yaml` - Optional enhanced RBAC for kubernetes-dashboard ServiceAccount

## RBAC Configuration

The dashboard is configured to use the `admin-user` ServiceAccount which has cluster-admin privileges. This allows full access to all cluster resources.

### Alternative RBAC Options:

1. **Current (Recommended for Development)**: Uses `admin-user` with cluster-admin permissions
2. **Restricted Access**: Uncomment and use `enhanced-rbac-optional.yaml` to grant only view permissions
3. **Custom Permissions**: Modify the ClusterRole in `enhanced-rbac-optional.yaml` for specific needs

## Configuration

The dashboard is configured to run in **insecure mode**:
- Dashboard runs on HTTP (port 9090)
- No internal HTTPS/TLS certificates required
- TLS termination happens at the Traefik ingress
- Simpler configuration and easier certificate management

## Setup

1. **Update the ingress host**: Edit `dashboard-ingress.yaml` and change `dashboard.example.com` to your actual domain
2. **TLS Certificate**: The ingress still provides HTTPS to users via the TLS secret
3. **Deploy via ArgoCD**: The application is configured in `/apps/dashboard.yaml`

## Access

### Via Ingress (Recommended)
Access the dashboard at: `https://your-domain.com` (HTTPS terminated at ingress)

### Via Port Forward (HTTP)
```bash
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8080:80
```
Then access at: `http://localhost:8080`

## Authentication

Use the admin user token for full cluster access:

```bash
kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath="{.data.token}" | base64 -d
```

## Security Notes

- ⚠️  **Dashboard runs in insecure mode** - HTTP only between ingress and dashboard
- ✅  **External access is still HTTPS** - TLS terminated at Traefik ingress
- ⚠️  **Admin-user has cluster-admin privileges** - use with caution in production
- ✅  **Simplified certificate management** - only ingress needs TLS certificates
- 💡  **Good for development** or when you have proper network security between ingress and pods

## Benefits of Insecure Mode

1. **Simpler setup** - No need to manage dashboard's internal certificates
2. **Easier debugging** - Can access dashboard directly via HTTP for troubleshooting
3. **Ingress TLS termination** - Centralized certificate management at ingress level
4. **Less resource usage** - Dashboard doesn't need to handle TLS encryption