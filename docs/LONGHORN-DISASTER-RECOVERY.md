# Longhorn Disaster Recovery Guide

## Scenario: Master Crashed, No Backup Available

**Current State**: Clean 7-node K3s cluster (3 masters, 4 workers)  
**Goal**: Recover Longhorn volumes from existing node storage  
**Date**: November 28, 2025

---

## Prerequisites Check

### 1. Verify Longhorn Data Still Exists
Run on **all nodes** that previously had Longhorn installed:

```bash
# Check if Longhorn data directory exists
ls -lah /var/lib/longhorn/

# Check disk usage (should show data if volumes existed)
du -sh /var/lib/longhorn/

# List replica directories
find /var/lib/longhorn/replicas -type d -name "pvc-*" 2>/dev/null | head -20
```

**Critical**: If you see volume data (replica directories, data files), your data is recoverable! 🎉

### 2. Document Current State
```bash
# Save list of existing volume data
for node in node1 node2 node3; do
  echo "=== $node ==="
  ssh $node "sudo find /var/lib/longhorn/replicas -type d -maxdepth 1 -name 'pvc-*' 2>/dev/null"
done > ~/longhorn-existing-volumes.txt

# Check available disk space on each node
kubectl get nodes -o custom-columns=NAME:.metadata.name,KUBELET_VERSION:.status.nodeInfo.kubeletVersion
for node in $(kubectl get nodes -o name | cut -d'/' -f2); do
  echo "=== $node ==="
  kubectl debug node/$node -it --image=busybox -- df -h | grep longhorn || echo "No Longhorn mount"
done
```

---

## Recovery Process

### Phase 1: Prepare Cluster (10 min)

#### 1.1 Ensure iSCSI is Installed on All Nodes
```bash
# Run on each node
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== Configuring $node ==="
  ssh $node "sudo apt-get update && sudo apt-get install -y open-iscsi util-linux && sudo systemctl enable iscsid && sudo systemctl start iscsid"
done
```

Or apply via kubectl:
```bash
kubectl apply -f infrastructure/longhorn/k3s-prerequisites.yaml
```

#### 1.2 Verify Node Labels (if you had specific node configurations)
```bash
# Check current node labels
kubectl get nodes --show-labels

# If needed, add labels for specific architectures
kubectl label nodes shuttle-192-168-1-12 kubernetes.io/arch=amd64
kubectl label nodes hp-192-168-1-6 kubernetes.io/arch=amd64
```

### Phase 2: Install Longhorn (DO NOT FORMAT DATA)

#### 2.1 Install Longhorn via ArgoCD
```bash
# Apply the Longhorn ArgoCD application
kubectl apply -f infrastructure/longhorn.yaml

# Monitor installation
kubectl get pods -n longhorn-system -w
```

**Expected**: Longhorn will:
1. Install CRDs and operator
2. Deploy manager pods on each node
3. **Automatically discover** existing volume data in `/var/lib/longhorn/`
4. Recreate volume resources in Kubernetes

#### 2.2 Wait for Longhorn to Stabilize (5-10 min)
```bash
# Wait for all pods to be running
kubectl wait --for=condition=ready pod -l app=longhorn-manager -n longhorn-system --timeout=300s

# Check Longhorn components
kubectl get pods -n longhorn-system
kubectl get daemonset -n longhorn-system
```

### Phase 3: Volume Discovery and Import

#### 3.1 Check Longhorn UI
Access Longhorn UI to see discovered volumes:
```bash
# Port forward to access UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```
Visit: http://localhost:8080

#### 3.2 Verify Volumes in CLI
```bash
# List discovered Longhorn volumes
kubectl get volumes -n longhorn-system

# Check volume status
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness
```

**Expected States**:
- `detached` - Volume found but not attached (normal if no pod using it)
- `healthy` - Volume is healthy with proper replica count
- `degraded` - Some replicas missing (recoverable)

#### 3.3 Check Replicas
```bash
# List all replicas
kubectl get replicas -n longhorn-system

# Check replica health
kubectl get replicas -n longhorn-system -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATE:.status.currentState
```

### Phase 4: Recreate PVs and PVCs

This is the **critical step** - Longhorn has the volume data, but Kubernetes doesn't know about the PVs/PVCs.

#### 4.1 List Discovered Volumes
```bash
# Get all Longhorn volumes
kubectl get volumes -n longhorn-system -o json > ~/longhorn-volumes.json

# Extract volume names
kubectl get volumes -n longhorn-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.kubernetesStatus.pvName}{"\t"}{.status.kubernetesStatus.pvcName}{"\t"}{.status.kubernetesStatus.namespace}{"\n"}' | column -t
```

#### 4.2 Manually Create PVs for Orphaned Volumes

For each volume that doesn't have a PV/PVC, create them manually:

```yaml
# Example: Create PV for volume pvc-12345678-1234-1234-1234-123456789abc
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pvc-12345678-1234-1234-1234-123456789abc
  annotations:
    pv.kubernetes.io/provisioned-by: driver.longhorn.io
spec:
  capacity:
    storage: 10Gi  # Match original size
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain  # Important: Use Retain during recovery
  storageClassName: longhorn
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeHandle: pvc-12345678-1234-1234-1234-123456789abc  # Longhorn volume name
    volumeAttributes:
      numberOfReplicas: "3"
      staleReplicaTimeout: "30"
```

#### 4.3 Create PVCs to Bind to PVs

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data  # Original PVC name if you remember it
  namespace: default  # Original namespace
  annotations:
    volume.beta.kubernetes.io/storage-provisioner: driver.longhorn.io
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: longhorn
  volumeName: pvc-12345678-1234-1234-1234-123456789abc  # Match PV name
```

### Phase 5: Restore Applications

#### 5.1 Identify Which PVCs Belong to Which Apps
Check your ArgoCD apps and deployment manifests:
```bash
# Search for PVC references in your configs
grep -r "persistentVolumeClaim" infrastructure/
grep -r "claimName" infrastructure/

# Check specific apps
cat infrastructure/firefly-iii/*.yaml | grep -A2 "persistentVolumeClaim"
cat infrastructure/paperless-ngx/*.yaml | grep -A2 "persistentVolumeClaim"
```

#### 5.2 Deploy Applications via ArgoCD
Once PVs and PVCs are recreated:
```bash
# Sync specific apps
kubectl apply -f apps.yaml
kubectl apply -f infrastructure.yaml

# Or sync individual apps
argocd app sync firefly-iii
argocd app sync paperless-ngx
argocd app sync home-assistant
```

---

## Automation Script

Here's a helper script to map volumes to PVCs:

```bash
#!/bin/bash
# longhorn-volume-recovery.sh

echo "=== Longhorn Volume Recovery Script ==="
echo "Date: $(date)"
echo ""

echo "Step 1: Checking Longhorn volumes..."
kubectl get volumes -n longhorn-system -o custom-columns=VOLUME:.metadata.name,SIZE:.spec.size,PV:.status.kubernetesStatus.pvName,PVC:.status.kubernetesStatus.pvcName,NS:.status.kubernetesStatus.namespace | tee ~/longhorn-volume-inventory.txt

echo ""
echo "Step 2: Finding orphaned volumes (no PV assigned)..."
kubectl get volumes -n longhorn-system -o json | jq -r '.items[] | select(.status.kubernetesStatus.pvName == null or .status.kubernetesStatus.pvName == "") | .metadata.name' | tee ~/longhorn-orphaned-volumes.txt

ORPHANED_COUNT=$(wc -l < ~/longhorn-orphaned-volumes.txt)
echo "Found $ORPHANED_COUNT orphaned volumes"

if [ $ORPHANED_COUNT -gt 0 ]; then
  echo ""
  echo "Step 3: Creating PV manifests for orphaned volumes..."
  mkdir -p ~/longhorn-recovery-pvs
  
  while read volume_name; do
    # Get volume size
    SIZE=$(kubectl get volume -n longhorn-system $volume_name -o jsonpath='{.spec.size}')
    
    cat > ~/longhorn-recovery-pvs/${volume_name}-pv.yaml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${volume_name}
  annotations:
    pv.kubernetes.io/provisioned-by: driver.longhorn.io
spec:
  capacity:
    storage: ${SIZE}
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: longhorn
  csi:
    driver: driver.longhorn.io
    fsType: ext4
    volumeHandle: ${volume_name}
    volumeAttributes:
      numberOfReplicas: "3"
      staleReplicaTimeout: "30"
EOF
    echo "Created PV manifest: ~/longhorn-recovery-pvs/${volume_name}-pv.yaml"
  done < ~/longhorn-orphaned-volumes.txt
  
  echo ""
  echo "Step 4: Review generated PV manifests in ~/longhorn-recovery-pvs/"
  echo "Then apply them: kubectl apply -f ~/longhorn-recovery-pvs/"
else
  echo "No orphaned volumes found - all volumes have PVs assigned!"
fi

echo ""
echo "=== Recovery Summary ==="
echo "Inventory saved to: ~/longhorn-volume-inventory.txt"
echo "Orphaned volumes: ~/longhorn-orphaned-volumes.txt"
echo "PV manifests: ~/longhorn-recovery-pvs/"
```

Save and run:
```bash
chmod +x longhorn-volume-recovery.sh
./longhorn-volume-recovery.sh
```

---

## Verification Steps

### 1. Check Volume Health
```bash
# All volumes should be healthy or degraded (recoverable)
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness

# Check for any failed replicas
kubectl get replicas -n longhorn-system | grep -i fail
```

### 2. Test Volume Mounting
Create a test pod to verify a volume can be mounted:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: volume-test
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'ls -la /data && df -h /data && sleep 3600']
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: <your-pvc-name>  # Replace with actual PVC
EOF

# Check if pod starts successfully
kubectl logs volume-test
kubectl exec -it volume-test -- ls -la /data
```

### 3. Verify Data Integrity
Once apps are running, verify data:
```bash
# Example for Firefly III
kubectl exec -it deployment/firefly-iii -n firefly-iii -- ls -la /var/www/html/storage/upload

# Example for Paperless
kubectl exec -it deployment/paperless-ngx -n paperless-ngx -- ls -la /usr/src/paperless/media
```

---

## Troubleshooting

### Problem: Volume shows "degraded" status
**Cause**: Some replicas are on nodes that no longer exist  
**Solution**:
```bash
# Longhorn will automatically rebuild missing replicas
# Monitor replica creation
kubectl get replicas -n longhorn-system -w

# Or manually trigger rebuild in Longhorn UI
```

### Problem: Volume shows "faulted" status
**Cause**: All replicas are unavailable  
**Solution**:
```bash
# Check replica status
kubectl get replicas -n longhorn-system | grep <volume-name>

# Check node connectivity
kubectl get nodes

# Restart Longhorn manager on affected nodes
kubectl delete pod -n longhorn-system -l app=longhorn-manager
```

### Problem: PV won't bind to PVC
**Cause**: Size mismatch or wrong storage class  
**Solution**:
```bash
# Check PV and PVC specs match
kubectl get pv <pv-name> -o yaml
kubectl get pvc <pvc-name> -n <namespace> -o yaml

# Ensure:
# - storage sizes match exactly
# - storageClassName matches
# - accessModes match
# - volumeName in PVC matches PV name
```

### Problem: Cannot find original PVC names/namespaces
**Solution**: Look for clues in volume data:
```bash
# Check volume metadata
kubectl get volume -n longhorn-system <volume-name> -o yaml

# Look for application-specific files in volume
kubectl debug node/<node-name> -it --image=busybox
# Then: ls -la /host/var/lib/longhorn/replicas/<volume-name>/
```

---

## Post-Recovery Recommendations

### 1. Enable etcd Snapshots
```bash
# On each master node
sudo k3s etcd-snapshot save --snapshot-retention 7

# Or configure in K3s config
# /etc/rancher/k3s/config.yaml
etcd-snapshot-schedule-cron: "0 */6 * * *"
etcd-snapshot-retention: 7
```

### 2. Enable Longhorn Backups
```bash
# Configure S3 backup target in Longhorn UI or via CLI
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Setting
metadata:
  name: backup-target
  namespace: longhorn-system
spec:
  value: "s3://your-bucket@region/backups"
---
apiVersion: longhorn.io/v1beta2  
kind: Setting
metadata:
  name: backup-target-credential-secret
  namespace: longhorn-system
spec:
  value: "longhorn-backup-secret"
EOF
```

### 3. Schedule Regular Snapshots
Create recurring snapshots for critical volumes in Longhorn UI or via:
```bash
# Example recurring job
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: daily-backup
  namespace: longhorn-system
spec:
  cron: "0 2 * * *"  # 2 AM daily
  task: "backup"
  retain: 7
  concurrency: 2
EOF
```

### 4. Document Your Setup
Create a volume inventory:
```bash
kubectl get pvc --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,VOLUME:.spec.volumeName,SIZE:.spec.resources.requests.storage,STORAGECLASS:.spec.storageClassName > ~/pvc-inventory.txt
```

---

## Quick Reference Commands

```bash
# Check Longhorn status
kubectl get pods -n longhorn-system
kubectl get volumes -n longhorn-system
kubectl get pv,pvc --all-namespaces | grep longhorn

# Access Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Force sync ArgoCD apps
argocd app sync --force longhorn
argocd app sync --force <app-name>

# Emergency: Check raw volume data on node
kubectl debug node/<node-name> -it --image=busybox
# Then: ls -la /host/var/lib/longhorn/replicas/
```

---

**Recovery Confidence**: HIGH ✅  
If your node disks are intact with `/var/lib/longhorn/` data, recovery is very likely to succeed!

Good luck with the recovery! 🚀
