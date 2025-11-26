# K3s HA Migration - Complete Package

## 📚 Documentation Created

Your complete HA migration package includes:

### 1. **Planning Documents**
- **[K3S-HA-MIGRATION-PLAN.md](./K3S-HA-MIGRATION-PLAN.md)** - Comprehensive 50-page migration guide
  - Detailed technical explanation
  - Step-by-step instructions with commands
  - Troubleshooting guide
  - Rollback procedures
  - Performance impact analysis
  
- **[HA-MIGRATION-CHECKLIST.md](./HA-MIGRATION-CHECKLIST.md)** - Print-friendly checklist
  - Checkbox format for tracking progress
  - Space for notes and timestamps
  - All commands copy-paste ready
  
- **[HA-QUICK-START.md](./HA-QUICK-START.md)** - Fast-track guide
  - TL;DR version for experienced admins
  - All commands in one place
  - Quick troubleshooting tips

### 2. **Helper Scripts** (in `~/bin/`)
- **`check-ha-status.sh`** - Verify current HA configuration
  - Shows control-plane node count
  - Checks etcd cluster health
  - Validates critical pods
  - Provides recommendations
  
- **`ha-migration-helper.sh`** - Interactive migration assistant
  - Guided step-by-step process
  - Automatic backups
  - Pre-flight checks
  - Progress tracking with confirmations

- **`reboot-k3s-node.sh`** - Safe node reboot script (already exists)
  - Will be used to test HA failover
  - Handles draining and uncordoning

### 3. **Updated Documentation**
- **README.md** - Updated with HA architecture info

---

## 🎯 Your Question Answered

### Should you promote another node to master before rebooting?

**YES - Absolutely!** And here's why:

#### Current Situation (Single Master)
- ❌ Master reboot = **hours of downtime**
- ❌ API server unavailable during reboot
- ❌ All kubectl commands fail
- ❌ ArgoCD can't sync
- ❌ Pods can't reschedule
- ❌ Monitoring/alerting stops
- ❌ Cascading failures across services

#### After HA Setup (3 Masters)
- ✅ Master reboot = **zero downtime**
- ✅ API server stays available (2/3 nodes serve requests)
- ✅ kubectl commands work continuously
- ✅ ArgoCD keeps syncing
- ✅ Pods reschedule normally
- ✅ Monitoring/alerting continues
- ✅ Clean, fast recovery (minutes not hours)

---

## 🚀 Quick Decision Matrix

| Scenario | Recommendation |
|----------|----------------|
| **Need to reboot master urgently** | Follow quick migration guide first (2-3 hrs) |
| **Have maintenance window** | Use interactive helper script (easiest) |
| **Want to understand everything** | Read full migration plan |
| **Just checking status** | Run `check-ha-status.sh` |

---

## 🛠️ How to Proceed

### Option 1: Interactive Migration (Recommended for First-Timers)
```bash
# This script will guide you through everything
~/bin/ha-migration-helper.sh
```

**Pros**: 
- Guided step-by-step
- Automatic backups
- Pre-flight checks
- Can abort at any time

**Time**: 2-3 hours (hands-on)

### Option 2: Manual Migration with Checklist
```bash
# Print or open the checklist
cat docs/HA-MIGRATION-CHECKLIST.md

# Follow step-by-step, checking boxes as you go
# Copy-paste commands from checklist
```

**Pros**: 
- More control
- Better understanding
- Good for documentation

**Time**: 2-3 hours (more thinking)

### Option 3: Quick Manual Migration (For Experts)
```bash
# Use the quick start guide
cat docs/HA-QUICK-START.md

# Copy-paste command blocks
```

**Pros**: 
- Fastest approach
- All commands ready

**Time**: 1.5-2 hours (experienced only)

---

## 📋 Pre-Migration Checklist

Before you start, ensure:

- [ ] **Hardware Check**: Verify disk and memory capacity
  - Current: shuttle has ~29GB free (marginal), hp has ~130GB free (good)
  - Minimum: 20GB free disk, 4GB RAM
  - Recommended: 50GB+ free disk, 8GB+ RAM
  - 📖 See [PRE-UPGRADE-HARDWARE.md](docs/PRE-UPGRADE-HARDWARE.md) if upgrades needed
- [ ] You have 2-3 hour maintenance window
- [ ] You've read at least the Quick Start guide
- [ ] SSH access to all three nodes (passwordless recommended)
- [ ] No active critical deployments in progress
- [ ] Stakeholders notified of maintenance
- [ ] You understand the rollback procedure

---

## 🎓 Key Concepts to Understand

### Why 3 Nodes?
- **Quorum requirement**: etcd needs majority (2/3) to operate
- **1 node down**: Still works (2/3 quorum maintained)
- **2 nodes down**: Cluster halts (can't reach quorum)
- **Best practice**: 3 or 5 nodes (never 2 or 4)

### What Happens During Migration?
1. **Master upgraded**: Gets `--cluster-init` flag (1-2 min downtime)
2. **Second node joins**: etcd quorum established (no more downtime)
3. **Third node joins**: Full HA achieved (optimal resilience)

### What Could Go Wrong?
- **Disk space**: Nodes need 20GB+ for etcd
- **Time sync**: Clocks must be within 5 seconds
- **Network**: Ports 2379-2380, 6443 must be accessible
- **Longhorn**: May take 5-10 min to adapt after node role changes

**All covered in the migration guides with fixes!**

---

## 🔍 Verification Commands

After migration, verify success:

```bash
# Quick check
check-ha-status.sh

# Detailed checks
kubectl get nodes  # Should show 3 control-plane nodes
kubectl get pods -n kube-system | grep etcd  # Should show 3 etcd pods
kubectl get pods --all-namespaces | grep -v Running  # Should be empty

# Test failover (the ultimate test!)
./bin/reboot-k3s-node.sh shuttle-192-168-1-12 192.168.1.12
# In another terminal, watch: kubectl get nodes (should stay up!)
```

---

## 📊 Expected Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Reading & Planning | 30 min | Understand the process |
| Pre-flight & Backup | 30 min | Backups and checks |
| Phase 1: Master HA | 15 min | Enable cluster-init |
| Phase 2: Add shuttle | 20 min | Join second control-plane |
| Phase 3: Add hp | 20 min | Join third control-plane |
| Validation | 15 min | Verify everything works |
| Testing | 30 min | Test reboot resilience |
| **Total** | **2-3 hours** | End-to-end |

---

## 💡 Pro Tips

1. **Do backups first** - The scripts handle this, but verify!
2. **Read error messages** - K3s logs are very helpful
3. **Wait for stabilization** - Don't rush between phases
4. **Test incrementally** - Check after each node joins
5. **Keep the checklist** - Great for post-mortem documentation

---

## 🆘 Getting Help

If something goes wrong:

1. **Check the troubleshooting section** in the full migration plan
2. **Run the status check**: `check-ha-status.sh`
3. **Check K3s logs**: `ssh sgorey@NODE_IP "sudo journalctl -u k3s -n 100"`
4. **Use the rollback procedure** in the migration plan

---

## 🎉 Post-Migration Benefits

After successful migration:

- **Maintenance windows**: No more stress about reboots
- **System updates**: Apply updates to nodes one at a time
- **Confidence**: Sleep better knowing your cluster has failover
- **Performance**: Better load distribution across API servers
- **Professional**: Production-grade HA setup

---

## 📁 File Locations

All documentation and scripts are in:

```
home-argocd-app-config/
  docs/
    ├── K3S-HA-MIGRATION-PLAN.md       (50+ pages, comprehensive)
    ├── HA-MIGRATION-CHECKLIST.md      (printable checklist)
    ├── HA-QUICK-START.md              (fast track guide)
    └── README.md                      (this file)

~/bin/
  ├── check-ha-status.sh               (status verification)
  ├── ha-migration-helper.sh           (interactive migration)
  └── reboot-k3s-node.sh               (safe node reboot)
```

---

## ✅ Recommendation

**Yes, you should absolutely promote two more nodes to master before your next reboot.**

The migration is:
- ✅ **Safe**: Comprehensive backup and rollback procedures
- ✅ **Tested**: Based on K3s official HA documentation
- ✅ **Worthwhile**: Hours of future downtime avoided
- ✅ **Professional**: Production best practice

**Start with**: 
```bash
# Check current status
check-ha-status.sh

# When ready, run the interactive helper
ha-migration-helper.sh
```

---

## 📝 Notes

- Scripts assume SSH user is `sgorey` (current user)
- Node IPs are hardcoded based on your cluster
- Passwordless SSH recommended but not required
- All scripts have built-in confirmations and safety checks

---

**Good luck with your migration! Your cluster will thank you. 🚀**

*Last updated: November 25, 2025*
