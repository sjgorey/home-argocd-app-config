# K3s HA Migration - Quick Start Guide

## TL;DR - The Fast Version

**What**: Convert your single-master K3s to 3-node HA  
**Why**: Eliminate hours of downtime when rebooting master  
**Time**: 2-3 hours  
**Risk**: Medium (with rollback plan)

---

## ⚠️ Hardware Check First!

Before starting, verify your nodes have sufficient resources:

```bash
# Check disk space (need 20GB minimum, 50GB+ recommended)
ssh sgorey@192.168.1.12 "df -h /"  # shuttle: ~29GB free (marginal)
ssh sgorey@192.168.1.6 "df -h /"   # hp: ~130GB free (good)

# Check memory (need 4GB minimum, 8GB+ recommended)  
ssh sgorey@192.168.1.12 "free -h"  # shuttle: 8GB (workable)
ssh sgorey@192.168.1.6 "free -h"   # hp: 8GB (workable)
```

**If you need more disk/memory**: See [PRE-UPGRADE-HARDWARE.md](./PRE-UPGRADE-HARDWARE.md)

---

## The Commands (Copy-Paste Version)

### 1. Backup (10 min) - REQUIRED

```bash
# On master
ssh sgorey@192.168.1.5 << 'EOF'
sudo k3s etcd-snapshot save --name pre-ha-$(date +%Y%m%d-%H%M%S)
sudo tar czf ~/k3s-backup-$(date +%Y%m%d).tar.gz \
  /etc/rancher/k3s/ \
  /var/lib/rancher/k3s/server/token \
  /var/lib/rancher/k3s/server/node-token
EOF

# Copy to workstation
scp sgorey@192.168.1.5:~/k3s-backup-*.tar.gz ~/backups/

# Save token
ssh sgorey@192.168.1.5 "sudo cat /var/lib/rancher/k3s/server/node-token" > ~/k3s-token.txt
export K3S_TOKEN=$(cat ~/k3s-token.txt)
```

---

### 2. Enable HA on Master (15 min)

```bash
# ⚠️ This will cause 1-2 min API downtime
ssh sgorey@192.168.1.5 << 'EOF'
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable=servicelb \
  --write-kubeconfig-mode=644
EOF

# Wait for stability
sleep 60
kubectl get nodes
```

---

### 3. Add shuttle as Control-Plane (20 min)

```bash
# Drain and prepare
kubectl cordon shuttle-192-168-1-12
kubectl drain shuttle-192-168-1-12 --ignore-daemonsets --delete-emptydir-data --force --timeout=10m

# Stop agent
ssh sgorey@192.168.1.12 "sudo systemctl stop k3s-agent && sudo systemctl disable k3s-agent"

# Join as server (use token from step 1)
ssh sgorey@192.168.1.12 << EOF
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://192.168.1.5:6443 \
  --token ${K3S_TOKEN} \
  --disable=servicelb \
  --write-kubeconfig-mode=644
EOF

# Wait and verify
sleep 60
kubectl get nodes
kubectl uncordon shuttle-192-168-1-12
```

---

### 4. Add hp as Control-Plane (20 min)

```bash
# Drain and prepare
kubectl cordon hp-192-168-1-6
kubectl drain hp-192-168-1-6 --ignore-daemonsets --delete-emptydir-data --force --timeout=10m

# Stop agent
ssh sgorey@192.168.1.6 "sudo systemctl stop k3s-agent && sudo systemctl disable k3s-agent"

# Join as server
ssh sgorey@192.168.1.6 << EOF
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://192.168.1.5:6443 \
  --token ${K3S_TOKEN} \
  --disable=servicelb \
  --write-kubeconfig-mode=644
EOF

# Wait and verify
sleep 60
kubectl get nodes
kubectl uncordon hp-192-168-1-6
```

---

### 5. Verify (5 min)

```bash
# Should see 3 control-plane nodes
kubectl get nodes

# Should see 3 etcd pods
kubectl get pods -n kube-system | grep etcd

# All pods should be running
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
```

---

### 6. Test Failover (10 min)

```bash
# Open two terminals

# Terminal 1: Watch nodes
watch kubectl get nodes

# Terminal 2: Reboot a control-plane node
./bin/reboot-k3s-node.sh shuttle-192-168-1-12 192.168.1.12

# Terminal 1 should show API stays up! 🎉
```

---

## One-Liner Status Check

```bash
kubectl get nodes -o custom-columns="NAME:.metadata.name,ROLE:.metadata.labels.node-role\.kubernetes\.io/,STATUS:.status.conditions[?(@.type=='Ready')].status" && \
kubectl get pods -n kube-system -l component=etcd && \
echo "=== etcd Members ===" && \
kubectl exec -n kube-system $(kubectl get pod -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl member list -w table 2>/dev/null || echo "etcd not ready yet"
```

---

## Emergency Rollback

```bash
# Stop everything
for node in 192.168.1.5 192.168.1.12 192.168.1.6; do
  ssh sgorey@$node "sudo systemctl stop k3s"
done

# Restore on master
ssh sgorey@192.168.1.5 << 'EOF'
sudo k3s server --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/pre-ha-*.db
sudo systemctl start k3s
EOF

# Wait 30 seconds
sleep 30

# Reinstall shuttle and hp as agents
for node in 192.168.1.12 192.168.1.6; do
  ssh sgorey@$node "curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.5:6443 K3S_TOKEN=${K3S_TOKEN} sh -"
done
```

---

## What You Get

**Before HA**:
- ❌ Reboot master → API down for hours
- ❌ Single point of failure
- ❌ Cascading pod failures
- ❌ Manual recovery needed

**After HA**:
- ✅ Reboot any control-plane → API stays up
- ✅ Automatic failover (2/3 quorum)
- ✅ Pods keep running
- ✅ Fast recovery (minutes not hours)

---

## Next Steps

1. ✅ Complete migration
2. ✅ Test reboot resilience
3. Set up automated etcd snapshots (optional)
4. Consider VIP/load balancer for API (optional)
5. Update monitoring dashboards (optional)

---

## Full Documentation

For detailed explanation, troubleshooting, and theory:
- 📖 **Full Plan**: `docs/K3S-HA-MIGRATION-PLAN.md`
- ✅ **Checklist**: `docs/HA-MIGRATION-CHECKLIST.md`

---

**Good luck! Your cluster will thank you. 🚀**
