# Manual Secret Creation

Since we don't want to store the actual SMTP password in git, create the secret manually:

## Option 1: Using kubectl directly
```bash
kubectl create secret generic smtp-credentials \
  --from-literal=password='YOUR_ACTUAL_PASSWORD' \
  -n smtp-relay
```

## Option 2: Create secret.yaml locally and apply
```bash
# Generate base64 encoded password
echo -n 'YOUR_ACTUAL_PASSWORD' | base64

# Create local secret.yaml (not committed to git)
cat > infrastructure/smtp-relay/secret-local.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: smtp-credentials
  namespace: smtp-relay
  labels:
    app: smtp-relay
type: Opaque
data:
  password: YOUR_BASE64_ENCODED_PASSWORD  # Replace with actual base64 encoded password
EOF

# Apply the secret
kubectl apply -f infrastructure/smtp-relay/secret-local.yaml
```

## Option 3: Use external secret management
Consider using tools like:
- Sealed Secrets
- External Secrets Operator
- Vault integration

## Update Instructions
To change the password:
1. Update the password in the external SMTP service
2. Update the secret: `kubectl patch secret smtp-credentials -n smtp-relay -p '{"data":{"password":"NEW_BASE64_PASSWORD"}}'`
3. Restart the SMTP relay deployment: `kubectl rollout restart deployment/smtp-relay -n smtp-relay`