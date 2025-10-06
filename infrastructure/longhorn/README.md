# Longhorn Storage for K3s with ArgoCD and Traefik

This directory contains the complete Longhorn distributed storage setup for K3s clusters, managed by ArgoCD with Traefik ingress.

## Files Overview

- `longhorn.yaml` - Main Longhorn installation manifest (generated from Helm chart)
- `longhorn-ingress.yaml` - Traefik ingress for Longhorn UI access
- `longhorn-tls-secret.yaml` - TLS certificate for HTTPS access
- `longhorn-auth.yaml` - Basic authentication setup for UI security
- `k3s-prerequisites.yaml` - K3s-specific requirements (iSCSI installation)
- `arch-storageclasses.yaml` - Architecture-specific StorageClasses (AMD64, ARM64, zones)
- `example-pvcs.yaml` - Example PVCs using different StorageClasses
- `direct-volumes.yaml` - Direct Longhorn Volume CRDs for advanced control

## Prerequisites

### 1. K3s Cluster Requirements
```bash
# Ensure all nodes have the required packages
sudo apt-get update
sudo apt-get install -y open-iscsi util-linux

# Enable and start iSCSI service on all nodes
sudo systemctl enable iscsid
sudo systemctl start iscsid
```

### 2. Node Storage Requirements
- Each node should have additional disk space for Longhorn storage
- Minimum 10GB available disk space per node
- SSD recommended for better performance

## Installation Steps

### 1. Update Configuration
```bash
# Update the domain in ingress
sed -i 's/longhorn.example.com/longhorn.yourdomain.com/g' longhorn-ingress.yaml
sed -i 's/longhorn.example.com/longhorn.yourdomain.com/g' longhorn-tls-secret.yaml

# Update the repository URL in ArgoCD app
sed -i 's|https://github.com/sjgorey/home-argocd-app-config|your-repo-url|g' ../../apps/longhorn.yaml
```

### 2. Deploy via ArgoCD
```bash
# Apply the ArgoCD application
kubectl apply -f ../../apps/longhorn.yaml

# Or apply manually for testing
kubectl apply -f k3s-prerequisites.yaml
kubectl apply -f longhorn.yaml
kubectl apply -f longhorn-auth.yaml
kubectl apply -f longhorn-tls-secret.yaml
kubectl apply -f longhorn-ingress.yaml
```

### 3. Verify Installation
```bash
# Check Longhorn pods
kubectl get pods -n longhorn-system

# Check storage class
kubectl get storageclass

# Check if Longhorn is set as default storage class
kubectl get storageclass longhorn
```

## Access

### Web UI Access
- **URL**: `https://longhorn.yourdomain.com`
- **Username**: `admin`
- **Password**: `longhorn123` (change this in `longhorn-auth.yaml`)

### Port Forward (Alternative)
```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Access at: http://localhost:8080
```

## Configuration

### Storage Class Settings
The default Longhorn storage class is configured with:
- **Replicas**: 3 (adjust based on node count)
- **Default**: true (set as default storage class)
- **Reclaim Policy**: Delete
- **Volume Binding**: Immediate

### Authentication
Currently configured with basic auth. For production, consider:
- Integration with external OAuth providers
- LDAP authentication
- Certificate-based authentication

### TLS Certificate
- Self-signed certificate included for `longhorn.example.com`
- For production, use:
  - Let's Encrypt with cert-manager
  - Valid SSL certificates
  - Update both ingress and secret accordingly

## Monitoring and Maintenance

### Health Checks
```bash
# Check Longhorn system health
kubectl get lhv -n longhorn-system  # Longhorn volumes
kubectl get lhe -n longhorn-system  # Longhorn engines
kubectl get lhr -n longhorn-system  # Longhorn replicas
kubectl get lhn -n longhorn-system  # Longhorn nodes
```

### Backup Configuration
Longhorn supports backups to:
- S3-compatible storage
- NFS shares
- Local storage

Configure backup targets in the Longhorn UI or via CRDs.

### Troubleshooting

#### Common Issues

1. **Pods stuck in Pending**: Check node storage requirements
2. **iSCSI errors**: Ensure open-iscsi is installed and running
3. **Volume attachment issues**: Check node connectivity and disk space
4. **UI access issues**: Verify ingress configuration and DNS

#### Useful Commands
```bash
# Check Longhorn system pods
kubectl get pods -n longhorn-system -o wide

# Check node preparation
kubectl get lhn -n longhorn-system

# View Longhorn events
kubectl get events -n longhorn-system --sort-by='.lastTimestamp'

# Check storage class
kubectl describe storageclass longhorn
```

## Security Considerations

1. **Change default credentials** in `longhorn-auth.yaml`
2. **Use proper TLS certificates** for production
3. **Restrict ingress access** by IP if needed
4. **Enable backup encryption** for sensitive data
5. **Regular security updates** for Longhorn components

## K3s Specific Notes

- K3s uses containerd by default - Longhorn supports this
- Local path provisioner is disabled when Longhorn becomes default
- Ensure sufficient disk space on all nodes
- Consider disabling K3s local storage if using Longhorn exclusively

## Upgrading

To upgrade Longhorn:
1. Update the image versions in `longhorn.yaml`
2. Commit and push to Git
3. ArgoCD will automatically apply the changes
4. Monitor the rollout in Longhorn UI

## Support

- [Longhorn Documentation](https://longhorn.io/docs/)
- [K3s Storage Documentation](https://rancher.com/docs/k3s/latest/en/storage/)
- [Troubleshooting Guide](https://longhorn.io/docs/latest/troubleshooting/)

## Example Usage

### Architecture-Specific Volumes

#### Option 1: Using StorageClasses (Recommended)
```bash
# Apply the architecture-specific StorageClasses
kubectl apply -f arch-storageclasses.yaml

# Create a PVC for AMD64 nodes
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-amd64-storage
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn-amd64
  resources:
    requests:
      storage: 10Gi
EOF
```

#### Option 2: Via Longhorn UI
1. Access Longhorn UI at your ingress URL
2. Go to "Volume" → "Create Volume"
3. Set "Node Selector" to `kubernetes.io/arch=amd64` (or `arm64`)
4. Configure size, replicas, and other settings

#### Option 3: Direct Volume CRDs
```bash
# Apply direct volume definitions
kubectl apply -f direct-volumes.yaml
```

### Available StorageClasses
- `longhorn-amd64` - Volumes on AMD64/x86_64 nodes
- `longhorn-arm64` - Volumes on ARM64 nodes  
- `longhorn-zone-a` - Volumes in specific zones
- `longhorn-local` - Single-replica local storage

### Creating a Persistent Volume
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn  # or longhorn-amd64, longhorn-arm64, etc.
  resources:
    requests:
      storage: 10Gi
```

### Using in a Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  nodeSelector:
    kubernetes.io/arch: amd64  # Match the storage architecture
  containers:
  - name: test-container
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: my-pvc
```