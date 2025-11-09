# Private Docker Registry

This deploys a private Docker registry to your K3s cluster with the following features:

## Features
- Persistent storage using Longhorn
- Basic authentication via Traefik middleware
- TLS termination with Let's Encrypt
- Health checks and monitoring
- Image deletion support

## Configuration

### 1. Update Domain
Edit `ingress.yaml` and replace `registry.yourdomain.com` with your actual domain.

### 2. Authentication
The default credentials are:
- Username: `admin`
- Password: `registry123`

To create new credentials:
```bash
# Generate new password hash
echo $(htpasswd -nB your-username) | sed -e s/\\$/\\$\\$/g

# Update the secret.yaml file with the output
```

### 3. Storage
- Default storage: 50Gi
- Storage class: `longhorn-amd64`
- Adjust in `pvc.yaml` if needed

## Usage

### Login to Registry
```bash
docker login registry.yourdomain.com
```

### Tag and Push Images
```bash
# Tag your image
docker tag my-image:latest registry.yourdomain.com/my-image:latest

# Push to registry
docker push registry.yourdomain.com/my-image:latest
```

### Pull Images
```bash
docker pull registry.yourdomain.com/my-image:latest
```

### Use in Kubernetes
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: my-app
        image: registry.yourdomain.com/my-image:latest
      imagePullSecrets:
      - name: registry-secret
```

### Create Image Pull Secret for Kubernetes
```bash
kubectl create secret docker-registry registry-secret \
  --docker-server=registry.yourdomain.com \
  --docker-username=admin \
  --docker-password=registry123 \
  --namespace=your-namespace
```

## Registry API

The registry provides a REST API:

### List repositories
```bash
curl -u admin:registry123 https://registry.yourdomain.com/v2/_catalog
```

### List tags for a repository
```bash
curl -u admin:registry123 https://registry.yourdomain.com/v2/my-image/tags/list
```

### Delete an image (if deletion is enabled)
```bash
# Get the digest
curl -u admin:registry123 -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  https://registry.yourdomain.com/v2/my-image/manifests/latest

# Delete using the digest
curl -u admin:registry123 -X DELETE \
  https://registry.yourdomain.com/v2/my-image/manifests/sha256:digest-here
```

## Monitoring

Check registry health:
```bash
curl https://registry.yourdomain.com/v2/
```

## Troubleshooting

### Check registry logs
```bash
kubectl -n registry logs deployment/registry
```

### Check storage usage
```bash
kubectl -n registry exec deployment/registry -- du -sh /var/lib/registry
```

### Registry not accessible
1. Check ingress configuration
2. Verify DNS points to your cluster
3. Check TLS certificate status
4. Verify authentication credentials