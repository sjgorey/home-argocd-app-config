# Local Docker Registry for k3s

This directory contains manifests to deploy a local, insecure Docker registry in your k3s cluster using Longhorn for persistent storage.

## Security
- No authentication or TLS is enabled.
- The registry is only accessible within the cluster (ClusterIP service).
- Ingress is provided for optional HTTP access (no SSL, no auth).

## Files
- `00-namespace.yaml`: Namespace for the registry
- `01-pvc.yaml`: Longhorn-backed PersistentVolumeClaim
- `02-deployment.yaml`: Registry Deployment (uses registry:2 image)
- `03-service.yaml`: ClusterIP Service on port 5000
- `04-ingress.yaml`: Ingress (HTTP, no auth, no SSL)

## Usage
Apply all manifests:

```sh
kubectl apply -f infrastructure/registry/
```

Push images from a node:

```sh
docker tag myimage:latest <registry-host>:5000/myimage:latest
docker push <registry-host>:5000/myimage:latest
```

Replace `<registry-host>` with the cluster node IP or the registry service DNS name (`registry.registry.svc.cluster.local:5000`).
