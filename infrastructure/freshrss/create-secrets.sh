#!/bin/bash

# FreshRSS Secret Creation Script
# Run this script before deploying to create the required secrets

set -e

echo "Creating FreshRSS secrets..."

# Generate secure random passwords
POSTGRES_PASSWORD=$(openssl rand -base64 16)
ADMIN_PASSWORD=$(openssl rand -base64 16)
ADMIN_EMAIL="steve.gorey+freshrss@gmail.com"

# Create the secret
kubectl create secret generic freshrss-secrets -n freshrss \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=admin-user="admin" \
  --from-literal=admin-password="$ADMIN_PASSWORD" \
  --from-literal=admin-email="$ADMIN_EMAIL" \
  --dry-run=client -o yaml > secret-real.yaml

echo "Secret manifest created in secret-real.yaml"
echo ""
echo "Generated credentials:"
echo "  Admin user: admin"
echo "  Admin password: $ADMIN_PASSWORD"
echo "  Admin email: $ADMIN_EMAIL"
echo "  DB password: $POSTGRES_PASSWORD"
echo ""
echo "To apply the secret, run:"
echo "  kubectl apply -f secret-real.yaml"
echo ""
echo "SAVE THESE CREDENTIALS SECURELY!"