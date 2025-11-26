# K3s High Availability (HA) Migration Plan

## Executive Summary

**Goal**: Convert single control-plane K3s cluster to 3-node HA setup to eliminate downtime during master reboots.

**Timeline**: 2-3 hours (with rollback capability)

**Risk Level**: Medium (comprehensive backup and rollback plan included)

---

## Current State

### Cluster Configuration
- **K3s Version**: v1.33.5+k3s1
- **Control Plane**: 1 node (single point of failure)
  - `thinkpad-192-168-1-5` (192.168.1.5)
- **Worker Nodes**: 6 nodes
  - AMD64: `hp-192-168-1-6`, `shuttle-192-168-1-12`
  - ARM64: `odroid1-4`

### Critical Workloads
- ArgoCD (GitOps controller)
- Prometheus + Grafana (monitoring)
- Loki (logging)
- Kafka cluster (3 brokers + 3 controllers)
- Multiple production apps with Longhorn PVs
- 26 persistent volumes (Longhorn distributed storage)

### Current Issue
When the master node reboots:
- ❌ API server goes offline (no pod scheduling)
- ❌ All kubectl commands fail
- ❌ ArgoCD can't sync applications
- ❌ Recovery takes hours due to cascading failures
- ❌ Single point of failure

---

## Target State (HA Configuration)

### 3-Node Control Plane
1. **thinkpad-192-168-1-5** (192.168.1.5) - existing master
2. **shuttle-192-168-1-12** (192.168.1.12) - promote to control-plane ⭐ BEST CHOICE
3. **hp-192-168-1-6** (192.168.1.6) - promote to control-plane

**Why these nodes?**
- All AMD64 (consistent architecture)
- `shuttle` has very low utilization (11% memory)
- `hp` has adequate resources (8GB RAM)
- Keep ARM64 nodes as pure workers

### HA Benefits
- ✅ **Zero API downtime** during any single node reboot
- ✅ **Automatic failover** via etcd quorum (2/3 nodes)
- ✅ **Load balancing** across API servers
- ✅ **Resilient updates** - rolling updates without downtime
- ✅ **Peace of mind** for maintenance

---

## Prerequisites Check

### ⚠️ IMPORTANT: Hardware Requirements

**Before proceeding**, verify your nodes meet these requirements:

#### Minimum Requirements (Will Work, But Tight)
- **Disk**: 20GB free space
- **Memory**: 4GB RAM

#### Recommended Requirements (Production Ready)
- **Disk**: 50GB+ free space (etcd grows over time)
- **Memory**: 8GB+ RAM (16GB ideal for control-plane)

**Current Node Status:**
- shuttle-192-168-1-12: ~29GB free disk, 8GB RAM ⚠️ (consider expanding disk)
- hp-192-168-1-6: ~130GB free disk, 8GB RAM ✅ (good to go)

📖 **See [PRE-UPGRADE-HARDWARE.md](./PRE-UPGRADE-HARDWARE.md) for hardware upgrade guidance**

If you need to upgrade hardware first, **do it before starting the HA migration**. It's much easier to upgrade worker nodes than control-plane nodes.

---

### 1. Verify Current Master Token
```bash
# On thinkpad-192-168-1-5
sudo cat /var/lib/rancher/k3s/server/node-token
```
**Save this token** - you'll need it for joining new servers.

### 2. Check Disk Space on Target Nodes
```bash
# On shuttle-192-168-1-12 and hp-192-168-1-6
ssh sgorey@192.168.1.12 "df -h /"
ssh sgorey@192.168.1.6 "df -h /"
```
**Need**: At least 20GB free for etcd data
**Recommended**: 50GB+ free space

### 3. Verify Network Connectivity
```bash
# From your workstation
for node in 192.168.1.5 192.168.1.12 192.168.1.6; do
  echo "Testing $node..."
  ssh sgorey@$node "hostname && date"
done
```

### 4. Check Time Synchronization
```bash
# etcd requires synchronized clocks
for node in 192.168.1.5 192.168.1.12 192.168.1.6; do
  ssh sgorey@$node "date +%s"
done
```
**Maximum drift**: ±5 seconds (install `chrony` or `systemd-timesyncd` if needed)

---

## Backup Strategy (CRITICAL - DO THIS FIRST!)

### 1. Create etcd Snapshot
```bash
# On thinkpad-192-168-1-5
sudo k3s etcd-snapshot save --name pre-ha-migration-$(date +%Y%m%d-%H%M%S)

# Verify snapshot
sudo ls -lh /var/lib/rancher/k3s/server/db/snapshots/
```

### 2. Backup Critical Configurations
```bash
# On thinkpad-192-168-1-5
sudo tar czf ~/k3s-config-backup-$(date +%Y%m%d).tar.gz \
  /etc/rancher/k3s/ \
  /var/lib/rancher/k3s/server/token \
  /var/lib/rancher/k3s/server/node-token

# Copy to safe location
scp ~/k3s-config-backup-*.tar.gz your-workstation:~/backups/
```

### 3. Document Current State
```bash
# Save current cluster state
kubectl get nodes -o yaml > ~/nodes-pre-ha.yaml
kubectl get pods --all-namespaces -o wide > ~/pods-pre-ha.txt
kubectl get pv,pvc --all-namespaces > ~/storage-pre-ha.txt

# Copy to workstation
scp ~/nodes-pre-ha.yaml ~/pods-pre-ha.txt ~/storage-pre-ha.txt your-workstation:~/backups/
```

### 4. Backup Longhorn Volumes (Optional but Recommended)
```bash
# Create backup snapshot for critical volumes via Longhorn UI
# Access: https://longhorn.yourdomain.com
# Navigate to: Volume → Select critical volumes → Take Snapshot
```

**Critical volumes to backup**:
- Prometheus data
- Grafana dashboards
- Kafka data
- Application databases

---

## Migration Steps

### Phase 1: Prepare Existing Master for HA

#### Step 1.1: Update K3s on Master to Support HA
```bash
# SSH to thinkpad-192-168-1-5
ssh sgorey@192.168.1.5

# Check if K3s is already configured with embedded etcd
sudo systemctl status k3s
sudo cat /etc/systemd/system/k3s.service | grep -i etcd

# If not already using embedded etcd, upgrade installation
# IMPORTANT: This will cause a brief API interruption (1-2 min)
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable=servicelb \
  --write-kubeconfig-mode=644

# Wait for cluster to stabilize
sudo systemctl status k3s
```

**Expected**: `--cluster-init` enables embedded etcd and prepares for HA

#### Step 1.2: Verify etcd is Running
```bash
# On thinkpad-192-168-1-5
sudo k3s etcd-snapshot ls

# Check etcd members (should show 1 member initially)
sudo k3s kubectl exec -n kube-system etcd-thinkpad-192-168-1-5 -- \
  etcdctl member list
```

#### Step 1.3: Get Join Configuration
```bash
# On thinkpad-192-168-1-5
# This is the token new servers will use
sudo cat /var/lib/rancher/k3s/server/node-token

# Save this to a secure file on your workstation
export K3S_TOKEN="<paste-token-here>"
export MASTER_IP="192.168.1.5"
```

---

### Phase 2: Add Second Control-Plane Node (shuttle-192-168-1-12)

#### Step 2.1: Prepare shuttle Node
```bash
# SSH to shuttle-192-168-1-12
ssh sgorey@192.168.1.12

# Drain and cordon the node from the existing cluster
# (Run this from your workstation first)
kubectl cordon shuttle-192-168-1-12
kubectl drain shuttle-192-168-1-12 --ignore-daemonsets --delete-emptydir-data --force
```

#### Step 2.2: Stop K3s Agent on shuttle
```bash
# On shuttle-192-168-1-12
sudo systemctl stop k3s-agent
sudo systemctl disable k3s-agent
```

#### Step 2.3: Join as Server Node
```bash
# On shuttle-192-168-1-12
# Use the token from Step 1.3
export K3S_TOKEN="<your-token>"
export MASTER_IP="192.168.1.5"

curl -sfL https://get.k3s.io | sh -s - server \
  --server https://${MASTER_IP}:6443 \
  --token ${K3S_TOKEN} \
  --disable=servicelb \
  --write-kubeconfig-mode=644

# Monitor the join process
sudo journalctl -u k3s -f
```

**Expected output**: Node joins cluster, etcd member added

#### Step 2.4: Verify etcd Quorum
```bash
# From your workstation or on any control-plane node
kubectl get nodes
# Should show shuttle-192-168-1-12 with role "control-plane,master"

# Check etcd members (should show 2 members)
kubectl exec -n kube-system etcd-thinkpad-192-168-1-5 -- \
  etcdctl --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  member list -w table
```

#### Step 2.5: Uncordon shuttle
```bash
# From workstation
kubectl uncordon shuttle-192-168-1-12
```

**⚠️ CHECKPOINT**: Verify cluster health before proceeding
```bash
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running
kubectl get componentstatuses  # Deprecated but useful
```

---

### Phase 3: Add Third Control-Plane Node (hp-192-168-1-6)

#### Step 3.1: Prepare hp Node
```bash
# From your workstation
kubectl cordon hp-192-168-1-6
kubectl drain hp-192-168-1-6 --ignore-daemonsets --delete-emptydir-data --force
```

#### Step 3.2: Stop K3s Agent on hp
```bash
# SSH to hp-192-168-1-6
ssh sgorey@192.168.1.6

sudo systemctl stop k3s-agent
sudo systemctl disable k3s-agent
```

#### Step 3.3: Join as Server Node
```bash
# On hp-192-168-1-6
export K3S_TOKEN="<your-token>"
export MASTER_IP="192.168.1.5"

curl -sfL https://get.k3s.io | sh -s - server \
  --server https://${MASTER_IP}:6443 \
  --token ${K3S_TOKEN} \
  --disable=servicelb \
  --write-kubeconfig-mode=644

# Monitor
sudo journalctl -u k3s -f
```

#### Step 3.4: Verify 3-Node etcd Cluster
```bash
# From workstation
kubectl get nodes
# Should show 3 nodes with "control-plane,master" role

# Verify etcd quorum (should show 3 members)
kubectl get pods -n kube-system -l component=etcd
```

#### Step 3.5: Uncordon hp
```bash
kubectl uncordon hp-192-168-1-6
```

---

### Phase 4: Configure HA Load Balancing (Optional but Recommended)

With 3 control-plane nodes, you can distribute API requests.

#### Option A: Update kubeconfig to Use All API Servers
```bash
# Edit ~/.kube/config
# Add all three API endpoints in a load-balanced fashion
# (K3s doesn't have built-in VIP, so this is manual)

# Current: server: https://192.168.1.5:6443
# HA Option: Use HAProxy or keepalived for VIP
```

#### Option B: DNS Round-Robin (Simple)
```bash
# Add to /etc/hosts on workstation and nodes
192.168.1.5  k3s-api
192.168.1.12 k3s-api
192.168.1.6  k3s-api

# Update kubeconfig
server: https://k3s-api:6443
```

#### Option C: Use HAProxy for VIP (Production)
This is more complex but provides a true VIP. Skip for now unless needed.

---

## Validation Tests

### Test 1: Verify etcd Health
```bash
# Check all etcd members are healthy
kubectl get pods -n kube-system -l component=etcd

# Detailed etcd status
kubectl exec -n kube-system etcd-thinkpad-192-168-1-5 -- \
  etcdctl endpoint health --cluster -w table
```

### Test 2: Verify Node Roles
```bash
kubectl get nodes -o custom-columns=\
"NAME:.metadata.name,\
ROLES:.metadata.labels,\
STATUS:.status.conditions[?(@.type=='Ready')].status"
```

### Test 3: Verify All Workloads Running
```bash
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
# Should return only header row
```

### Test 4: Test API Failover
```bash
# Reboot one control-plane node
./bin/reboot-k3s-node.sh shuttle-192-168-1-12 192.168.1.12

# While rebooting, verify API is still accessible
watch kubectl get nodes
# Should continue working without interruption
```

### Test 5: Verify Longhorn Replication
```bash
kubectl get volumes -n longhorn-system
# Ensure volumes are healthy and replicated
```

---

## Rollback Plan (If Something Goes Wrong)

### If Migration Fails During Phase 2 or 3

#### Quick Rollback: Restore from etcd Snapshot
```bash
# On thinkpad-192-168-1-5
# Stop K3s on ALL nodes first
for node in 192.168.1.5 192.168.1.12 192.168.1.6; do
  ssh sgorey@$node "sudo systemctl stop k3s"
done

# On thinkpad-192-168-1-5, restore snapshot
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/pre-ha-migration-*.db

# Restart K3s on master
sudo systemctl start k3s

# Restart agents on worker nodes (not shuttle or hp)
for node in 192.168.1.21 192.168.1.22 192.168.1.23 192.168.1.24; do
  ssh sgorey@$node "sudo systemctl restart k3s-agent"
done

# Reinstall shuttle and hp as agents
ssh sgorey@192.168.1.12 "curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.5:6443 K3S_TOKEN=<token> sh -"
ssh sgorey@192.168.1.6 "curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.5:6443 K3S_TOKEN=<token> sh -"
```

### If Cluster is Completely Broken
1. Restore from etcd snapshot (above)
2. Restore Longhorn volumes from snapshots
3. Redeploy ArgoCD applications

---

## Post-Migration Tasks

### 1. Update Documentation
```bash
# Update README.md with new HA architecture
# Document new node roles
```

### 2. Test Reboot Resilience
```bash
# Test rebooting each control-plane node one at a time
./bin/reboot-k3s-node.sh thinkpad-192-168-1-5 192.168.1.5
# Verify API stays up

./bin/reboot-k3s-node.sh shuttle-192-168-1-12 192.168.1.12
# Verify API stays up

./bin/reboot-k3s-node.sh hp-192-168-1-6 192.168.1.6
# Verify API stays up
```

### 3. Update Monitoring
```bash
# Add etcd metrics to Prometheus
# Add alerts for etcd cluster health
# Update Grafana dashboards
```

### 4. Schedule Regular etcd Snapshots
```bash
# Add cron job on each control-plane node
# Create on thinkpad, shuttle, and hp

sudo crontab -e

# Add:
0 2 * * * /usr/local/bin/k3s etcd-snapshot save --name scheduled-$(date +\%Y\%m\%d-\%H\%M) --snapshot-compress
```

### 5. Test Backup/Restore Process
```bash
# Create test snapshot
sudo k3s etcd-snapshot save --name test-restore-$(date +%Y%m%d)

# Practice restore (on a test cluster or non-prod time)
```

---

## Troubleshooting Guide

### Issue: Node Won't Join etcd Cluster

**Symptoms**: New server node stuck in "NotReady" state

**Check**:
```bash
# On the new node
sudo journalctl -u k3s -n 100

# Look for errors like:
# - "etcd cluster is unavailable"
# - "connection refused"
# - "certificate not valid"
```

**Fix**:
1. Verify token is correct
2. Check firewall (ports 2379-2380, 6443 must be open)
3. Verify time sync (max 5 sec drift)
4. Ensure K3s on master has `--cluster-init` flag

### Issue: etcd Quorum Lost

**Symptoms**: API server unavailable even with HA

**Check**:
```bash
kubectl get pods -n kube-system | grep etcd
```

**Fix**: Need 2/3 nodes healthy. If only 1 node up, restore from backup.

### Issue: Pods Not Scheduling After Migration

**Check**:
```bash
kubectl get nodes
kubectl describe node <node-name> | grep Taints
```

**Fix**:
```bash
kubectl uncordon <node-name>
kubectl taint nodes <node-name> node-role.kubernetes.io/master:NoSchedule-
```

### Issue: Longhorn Volumes Not Accessible

**Check**:
```bash
kubectl get volumes -n longhorn-system
kubectl logs -n longhorn-system -l app=longhorn-manager
```

**Fix**: Longhorn should automatically handle node changes. Wait 5-10 minutes.

---

## Performance Impact

### Expected During Migration
- **Phase 1**: 1-2 min API interruption when adding `--cluster-init`
- **Phase 2 & 3**: No interruption (etcd quorum maintained)
- **Pod Rescheduling**: 5-10 minutes for pods to stabilize

### Expected After Migration
- **Slight increase** in etcd resource usage (3 nodes syncing)
- **No impact** on application performance
- **Faster recovery** from node failures

---

## Estimated Timeline

| Phase | Duration | Can Fail? |
|-------|----------|-----------|
| Prerequisites & Backup | 30 min | No |
| Phase 1 (Prep Master) | 15 min | Yes - Rollback easy |
| Phase 2 (Add shuttle) | 20 min | Yes - Rollback moderate |
| Phase 3 (Add hp) | 20 min | Yes - Rollback harder |
| Validation | 15 min | N/A |
| Testing | 30 min | N/A |
| **Total** | **~2-3 hours** | |

---

## Decision Point: Proceed?

### ✅ Proceed If:
- Backups completed successfully
- All prerequisites passed
- You have 2-3 hour maintenance window
- You understand rollback procedure

### ⚠️ Wait If:
- Active production deployments in progress
- Less than 20GB free disk on target nodes
- Time sync issues (>5 sec drift)
- Recent cluster instability

---

## Success Criteria

After migration, you should be able to:
1. ✅ Reboot any single control-plane node without API downtime
2. ✅ See 3 control-plane nodes in `kubectl get nodes`
3. ✅ See 3 etcd members in `etcdctl member list`
4. ✅ All pods remain in "Running" state during node reboots
5. ✅ ArgoCD continues syncing during node reboots
6. ✅ Prometheus/Grafana continue monitoring during reboots

---

## References

- [K3s HA Embedded etcd](https://docs.k3s.io/datastore/ha-embedded)
- [K3s Backup and Restore](https://docs.k3s.io/backup-restore)
- [etcd Disaster Recovery](https://etcd.io/docs/v3.5/op-guide/recovery/)

---

## Notes

- This plan assumes K3s is using default embedded SQLite on the master. If already using external database or etcd, the plan needs adjustment.
- Longhorn provides storage resilience independently of control-plane HA
- Consider adding a VIP (Virtual IP) via HAProxy/keepalived for production use

---

**Created**: November 25, 2025  
**Author**: System Administrator  
**Status**: Ready for Review
