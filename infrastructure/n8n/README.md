# n8n Workflow Automation

n8n is a powerful workflow automation tool that helps you connect different services and automate tasks.

## Deployment

- **Namespace**: `n8n` (dedicated namespace for isolation)
- **URL**: http://n8n.example.com
- **First Run**: n8n will prompt you to create an admin account on first access

## Features

- ✅ **Persistent Storage**: 5GB Longhorn volume for workflows and data
- ✅ **HTTP Access**: Available at http://n8n.example.com (matches other cluster services)
- ✅ **Webhook Support**: External webhook URL configured
- ✅ **Security**: Network policies and encrypted data
- ✅ **Multi-arch**: Supports both x86_64 and ARM64 nodes

## Configuration

- **Database**: SQLite (file-based, stored in persistent volume)
- **Timezone**: America/New_York
- **Encryption**: Enabled with secret key
- **Metrics**: Enabled for monitoring integration

## Initial Setup

1. Navigate to http://n8n.example.com
2. Create your admin account
3. Start building workflows!

## Common Workflows

n8n excels at:
- API integrations and data synchronization
- Monitoring and alerting workflows  
- Data processing and transformation
- Webhook handling and notifications
- Scheduled tasks and automation

## Storage

- **Volume**: 5GB persistent storage via Longhorn
- **Path**: `/home/node/.n8n` (workflows, credentials, database)
- **Backup**: Included in Longhorn snapshots

## Security Notes

- Change the encryption key in `secret.yaml` before deployment
- Use strong passwords for your admin account
- Review network policies for your security requirements
- Consider setting up backup procedures for workflow data

## Monitoring

n8n exposes metrics on the `/metrics` endpoint for Prometheus integration.

## Scaling

This setup uses SQLite and is designed for single-replica deployment. For high availability:
1. Switch to PostgreSQL database
2. Add Redis for queue management  
3. Enable multiple replicas
4. Use external session storage