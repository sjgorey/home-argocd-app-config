#!/bin/bash

# Paperless-NGX Secret Creation Script
# Run this script before deploying to create the required secrets

set -e

echo "Creating Paperless-NGX secrets..."

# Generate secure random passwords
SECRET_KEY=$(openssl rand -base64 32)
ADMIN_PASSWORD=$(openssl rand -base64 16)
DB_PASSWORD=$(openssl rand -base64 16)
ADMIN_EMAIL="steve.gorey+paperless@example.com"

# Create the secret
kubectl create secret generic paperless-secrets -n paperless-ngx \
  --from-literal=secret-key="$SECRET_KEY" \
  --from-literal=admin-user="admin" \
  --from-literal=admin-password="$ADMIN_PASSWORD" \
  --from-literal=admin-email="$ADMIN_EMAIL" \
  --from-literal=db-name="paperless" \
  --from-literal=db-user="paperless" \
  --from-literal=db-password="$DB_PASSWORD" \
  --dry-run=client -o yaml > secret-real.yaml

echo "Secret manifest created in secret-real.yaml"
echo ""
echo "Generated credentials:"
echo "  Admin user: admin"
echo "  Admin password: $ADMIN_PASSWORD"
echo "  Admin email: $ADMIN_EMAIL"
echo "  DB password: $DB_PASSWORD"
echo ""
echo "To apply the secret, run:"
echo "  kubectl apply -f secret-real.yaml"
echo ""
echo "SAVE THESE CREDENTIALS SECURELY!"