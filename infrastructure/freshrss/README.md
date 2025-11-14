# FreshRSS

FreshRSS is a self-hosted RSS feed reader that helps you organize and read your news feeds.

## Components

- **FreshRSS**: Main RSS reader application
- **PostgreSQL**: Database for feed data and user settings

## Access

- URL: https://freshrss.example.com
- Admin user will be created during setup using credentials from the secret

## Storage

- FreshRSS Data: `/var/www/FreshRSS/data` (5GB)
- Extensions: `/var/www/FreshRSS/extensions` (1GB)
- PostgreSQL: Database storage (10GB)

## Configuration

### Environment Variables
- **CRON_MIN**: Feed update interval (default: */15 - every 15 minutes)
- **TZ**: Timezone (America/New_York)
- **TRUSTED_PROXY**: K3s cluster networks for proper client IP detection

### Database
- **Type**: PostgreSQL 15
- **Database**: freshrss
- **User**: freshrss
- **Password**: Generated automatically (see secrets)

## Setup Instructions

### 1. Create Secrets
```bash
cd infrastructure/freshrss
./create-secrets.sh
kubectl apply -f secret-real.yaml
```

### 2. Update Domain
Edit `04-ingress.yaml` and change `freshrss.example.com` to your actual domain.

### 3. Deploy via ArgoCD
Add to your ArgoCD applications or apply manually:
```bash
kubectl apply -f .
```

### 4. Initial Setup
1. Access FreshRSS via your configured domain
2. Follow the setup wizard
3. Configure database connection (should auto-detect from environment)
4. Create your admin user
5. Start adding RSS feeds

## Features

- **Multi-user support**: Create accounts for family/team members
- **Feed organization**: Categories, tags, and filters
- **Reading modes**: List, expanded, global view
- **Mobile responsive**: Works great on phones and tablets
- **Extensions**: Support for additional functionality
- **API access**: Compatible with mobile RSS apps
- **Import/Export**: OPML support for feed backup/migration

## Maintenance

### Feed Updates
Feeds are automatically updated based on the CRON_MIN setting (every 15 minutes by default).

### Backup
Important data to backup:
- FreshRSS data volume (`freshrss-data-pvc`)
- PostgreSQL database
- Extension configurations

### Updates
Update the FreshRSS container image by changing the tag in `03-deployment.yaml` and redeploying.

## Security

- Runs as non-root user (www-data)
- No privileged escalation
- Database credentials stored in Kubernetes secrets
- TLS encryption via Traefik ingress
- Trusted proxy configuration for proper client IP handling

## Troubleshooting

### Common Issues
1. **Database connection errors**: Check PostgreSQL pod logs and ensure secret is applied
2. **Feed update problems**: Check CRON_MIN setting and container logs
3. **Access issues**: Verify ingress domain and TLS certificate

### Useful Commands
```bash
# Check application logs
kubectl logs -n freshrss deployment/freshrss -f

# Check database logs
kubectl logs -n freshrss deployment/freshrss-postgres -f

# Access database directly
kubectl exec -it -n freshrss deployment/freshrss-postgres -- psql -U freshrss -d freshrss

# Restart application
kubectl rollout restart deployment/freshrss -n freshrss
```