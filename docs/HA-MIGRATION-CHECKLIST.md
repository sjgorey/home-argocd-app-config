# K3s HA Migration - Quick Checklist

**Date**: _______________  
**Engineer**: _______________

## Pre-Flight Checklist

- [ ] Read full migration plan: `docs/K3S-HA-MIGRATION-PLAN.md`
- [ ] Schedule 3-hour maintenance window
- [ ] Notify stakeholders of maintenance
- [ ] Confirm no active deployments in progress

### Prerequisites (30 min)

- [ ] **Backup etcd snapshot**
  ```bash
  ssh sgorey@192.168.1.5 "sudo k3s etcd-snapshot save --name pre-ha-$(date +%Y%m%d-%H%M%S)"
  ```
  Snapshot location: _______________

- [ ] **Backup K3s configs**
  ```bash
  ssh sgorey@192.168.1.5 "sudo tar czf ~/k3s-backup-$(date +%Y%m%d).tar.gz /etc/rancher/k3s/ /var/lib/rancher/k3s/server/token /var/lib/rancher/k3s/server/node-token"
  scp sgorey@192.168.1.5:~/k3s-backup-*.tar.gz ~/backups/
  ```
  Backup location: _______________

- [ ] **Save cluster state**
  ```bash
  kubectl get nodes -o yaml > ~/nodes-pre-ha.yaml
  kubectl get pods --all-namespaces -o wide > ~/pods-pre-ha.txt
  kubectl get pv,pvc --all-namespaces > ~/storage-pre-ha.txt
  ```

- [ ] **Get and save master token**
  ```bash
  ssh sgorey@192.168.1.5 "sudo cat /var/lib/rancher/k3s/server/node-token"
  ```
  Token (save securely): _______________

- [ ] **Check disk space on target nodes**
  ```bash
  ssh sgorey@192.168.1.12 "df -h /"
  ssh sgorey@192.168.1.6 "df -h /"
  ```
  shuttle free space: _______________ (Current: ~29GB)
  hp free space: _______________ (Current: ~130GB)
  
  **Requirements:**
  - Minimum: >20GB each ⚠️
  - Recommended: >50GB each ✅
  
  ⚠️ **If insufficient**: See docs/PRE-UPGRADE-HARDWARE.md for upgrade guide

- [ ] **Check time sync**
  ```bash
  for node in 192.168.1.5 192.168.1.12 192.168.1.6; do
    ssh sgorey@$node "date +%s"
  done
  ```
  Max drift: _____ seconds (must be <5)

---

## Phase 1: Prepare Master for HA (15 min)

- [ ] **Enable cluster-init on master**
  ```bash
  ssh sgorey@192.168.1.5
  curl -sfL https://get.k3s.io | sh -s - server \
    --cluster-init \
    --disable=servicelb \
    --write-kubeconfig-mode=644
  ```
  ⚠️ **Expected**: 1-2 min API downtime

- [ ] **Verify K3s restarted**
  ```bash
  ssh sgorey@192.168.1.5 "sudo systemctl status k3s"
  ```

- [ ] **Verify etcd is running**
  ```bash
  ssh sgorey@192.168.1.5 "sudo k3s etcd-snapshot ls"
  ```

- [ ] **Wait for cluster to stabilize**
  ```bash
  kubectl get nodes
  kubectl get pods --all-namespaces | grep -v Running
  ```
  Time cluster stabilized: _______________

---

## Phase 2: Add shuttle-192-168-1-12 (20 min)

- [ ] **Drain shuttle node**
  ```bash
  kubectl cordon shuttle-192-168-1-12
  kubectl drain shuttle-192-168-1-12 --ignore-daemonsets --delete-emptydir-data --force --timeout=10m
  ```

- [ ] **Stop K3s agent on shuttle**
  ```bash
  ssh sgorey@192.168.1.12 "sudo systemctl stop k3s-agent && sudo systemctl disable k3s-agent"
  ```

- [ ] **Join shuttle as server**
  ```bash
  ssh sgorey@192.168.1.12
  export K3S_TOKEN="<paste-token-here>"
  curl -sfL https://get.k3s.io | sh -s - server \
    --server https://192.168.1.5:6443 \
    --token ${K3S_TOKEN} \
    --disable=servicelb \
    --write-kubeconfig-mode=644
  ```

- [ ] **Monitor join process**
  ```bash
  ssh sgorey@192.168.1.12 "sudo journalctl -u k3s -f"
  ```
  Wait for: "Joining member..." and "member added"

- [ ] **Verify shuttle joined**
  ```bash
  kubectl get nodes
  ```
  shuttle role should be: "control-plane,master"

- [ ] **Verify etcd has 2 members**
  ```bash
  kubectl get pods -n kube-system | grep etcd
  ```
  Should see 2 etcd pods

- [ ] **Uncordon shuttle**
  ```bash
  kubectl uncordon shuttle-192-168-1-12
  ```

- [ ] **🚨 CHECKPOINT: Verify cluster health**
  ```bash
  kubectl get nodes
  kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
  ```
  All pods running: [ ] YES [ ] NO

---

## Phase 3: Add hp-192-168-1-6 (20 min)

- [ ] **Drain hp node**
  ```bash
  kubectl cordon hp-192-168-1-6
  kubectl drain hp-192-168-1-6 --ignore-daemonsets --delete-emptydir-data --force --timeout=10m
  ```

- [ ] **Stop K3s agent on hp**
  ```bash
  ssh sgorey@192.168.1.6 "sudo systemctl stop k3s-agent && sudo systemctl disable k3s-agent"
  ```

- [ ] **Join hp as server**
  ```bash
  ssh sgorey@192.168.1.6
  export K3S_TOKEN="<paste-token-here>"
  curl -sfL https://get.k3s.io | sh -s - server \
    --server https://192.168.1.5:6443 \
    --token ${K3S_TOKEN} \
    --disable=servicelb \
    --write-kubeconfig-mode=644
  ```

- [ ] **Monitor join process**
  ```bash
  ssh sgorey@192.168.1.6 "sudo journalctl -u k3s -f"
  ```

- [ ] **Verify hp joined**
  ```bash
  kubectl get nodes
  ```
  hp role should be: "control-plane,master"

- [ ] **Verify etcd has 3 members**
  ```bash
  kubectl get pods -n kube-system | grep etcd
  ```
  Should see 3 etcd pods

- [ ] **Uncordon hp**
  ```bash
  kubectl uncordon hp-192-168-1-6
  ```

---

## Validation Tests (15 min)

- [ ] **Test 1: All nodes show correct roles**
  ```bash
  kubectl get nodes
  ```
  Expected: 3 control-plane nodes, 4 worker nodes

- [ ] **Test 2: All pods running**
  ```bash
  kubectl get pods --all-namespaces | grep -v Running | grep -v Completed
  ```
  Non-running pods: _______________

- [ ] **Test 3: etcd cluster healthy**
  ```bash
  kubectl get pods -n kube-system -l component=etcd
  ```
  All 3 etcd pods running: [ ] YES [ ] NO

- [ ] **Test 4: ArgoCD syncing**
  ```bash
  kubectl get applications -n argocd
  ```
  All apps synced: [ ] YES [ ] NO

- [ ] **Test 5: Longhorn healthy**
  ```bash
  kubectl get volumes -n longhorn-system | head -10
  ```
  Volumes healthy: [ ] YES [ ] NO

---

## Failover Test (30 min)

- [ ] **Test reboot shuttle (should have NO API downtime)**
  ```bash
  ./bin/reboot-k3s-node.sh shuttle-192-168-1-12 192.168.1.12
  ```
  In another terminal:
  ```bash
  watch kubectl get nodes
  ```
  API stayed up during reboot: [ ] YES [ ] NO

- [ ] **Wait for shuttle to rejoin**
  Time to rejoin: _______________

- [ ] **Verify all pods recovered**
  ```bash
  kubectl get pods --all-namespaces | grep -v Running
  ```

---

## Post-Migration (15 min)

- [ ] **Create post-migration snapshot**
  ```bash
  ssh sgorey@192.168.1.5 "sudo k3s etcd-snapshot save --name post-ha-$(date +%Y%m%d-%H%M%S)"
  ```

- [ ] **Document new topology**
  - Update `README.md` with HA architecture
  - Note which nodes are control-plane

- [ ] **Set up automated etcd snapshots**
  ```bash
  for node in 192.168.1.5 192.168.1.12 192.168.1.6; do
    ssh sgorey@$node "echo '0 2 * * * /usr/local/bin/k3s etcd-snapshot save --name scheduled-\$(date +\%Y\%m\%d-\%H\%M)' | sudo crontab -"
  done
  ```

- [ ] **Update monitoring alerts** (if applicable)
  - Add etcd health checks
  - Update node down alerts for HA

- [ ] **Notify stakeholders of completion**

---

## Rollback (If Needed)

If something goes wrong:

```bash
# Stop K3s on all nodes
for node in 192.168.1.5 192.168.1.12 192.168.1.6; do
  ssh sgorey@$node "sudo systemctl stop k3s"
done

# On master, restore snapshot
ssh sgorey@192.168.1.5 "sudo k3s server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/pre-ha-*.db"

# Restart master
ssh sgorey@192.168.1.5 "sudo systemctl start k3s"

# Rejoin shuttle and hp as agents
ssh sgorey@192.168.1.12 "curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.5:6443 K3S_TOKEN=<token> sh -"
ssh sgorey@192.168.1.6 "curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.5:6443 K3S_TOKEN=<token> sh -"
```

---

## Sign-Off

- [ ] Migration completed successfully
- [ ] All tests passed
- [ ] Documentation updated
- [ ] Stakeholders notified

**Completion Time**: _______________  
**Total Duration**: _______________  
**Issues Encountered**: _______________

**Signature**: _______________
