# Hardware Upgrade Before HA Migration

## Current Hardware Status

### shuttle-192-168-1-12
- **Disk**: 54GB total, 29GB free (45% used)
- **Memory**: 7.6GB RAM
- **Status**: ⚠️ Minimal for control-plane duties

### hp-192-168-1-6
- **Disk**: 218GB total, 130GB free (38% used)
- **Memory**: 7.7GB RAM  
- **Status**: ✅ Good capacity, but more RAM recommended for control-plane

---

## Recommended Upgrades

### For Control-Plane Duties

Control-plane nodes run additional services:
- **etcd** (distributed database) - CPU and I/O intensive
- **kube-apiserver** (API endpoint) - Memory intensive
- **kube-controller-manager** - Memory intensive
- **kube-scheduler** - CPU intensive

#### Recommended Specs Per Control-Plane Node
- **Disk**: 100GB+ free space
  - etcd database grows over time
  - Snapshots take space
  - System logs
  - Container images
- **Memory**: 8GB minimum, 16GB+ recommended
  - Base K3s: ~2GB
  - etcd: ~1-2GB
  - System overhead: ~1GB
  - Remaining for workloads: 4GB+

### Priority Upgrades

#### High Priority: shuttle-192-168-1-12
**Disk**: Consider expanding to 100GB+ total
- Current: 54GB (might be tight with etcd growth)
- Options:
  - Expand LVM volume (if space available on disk)
  - Add/replace disk
  - Clean up old data

**Memory**: Consider upgrading to 16GB
- Current: 8GB is workable but tight
- Control-plane + workload pods will compete

#### Medium Priority: hp-192-168-1-6  
**Disk**: Already sufficient (218GB)
- 130GB free is plenty for control-plane duties

**Memory**: Consider upgrading to 16GB
- Current: 8GB is workable
- More headroom = better stability

---

## Upgrade Sequence

### Step 1: Check LVM Space (shuttle)

```bash
# SSH to shuttle
ssh sgorey@192.168.1.12

# Check if there's free space in volume group
sudo vgs
sudo pvs
sudo lvs

# If there's free space, expand the logical volume
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```

### Step 2: Physical Upgrades (if needed)

For each node that needs hardware upgrades:

1. **Drain the node** (remove workloads safely)
   ```bash
   kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
   ```

2. **Power down and upgrade**
   - Add/replace disk
   - Add memory modules
   - Ensure hardware compatibility

3. **Boot up and verify**
   ```bash
   # Check new capacity
   ssh sgorey@<node-ip> "df -h / && free -h"
   ```

4. **Uncordon the node** (allow workloads back)
   ```bash
   kubectl uncordon <node-name>
   ```

### Step 3: Verify Before HA Migration

Before proceeding with HA migration, verify:

```bash
# Check disk space (should have 50GB+ free)
ssh sgorey@192.168.1.12 "df -h /"
ssh sgorey@192.168.1.6 "df -h /"

# Check memory (should have 8GB+ total)
ssh sgorey@192.168.1.12 "free -h"
ssh sgorey@192.168.1.6 "free -h"
```

**Minimum for HA Migration:**
- ✅ 20GB free disk space
- ✅ 4GB RAM (absolute minimum)

**Recommended for HA Migration:**
- ✅ 50GB free disk space
- ✅ 8GB+ RAM

---

## Current Assessment

Based on current state:

| Node | Disk Free | RAM | HA Ready? | Recommendation |
|------|-----------|-----|-----------|----------------|
| shuttle | 29GB | 8GB | ⚠️ Marginal | Expand disk to 100GB+, consider 16GB RAM |
| hp | 130GB | 8GB | ✅ Yes | Optional: upgrade to 16GB RAM for better headroom |

### Can You Proceed Now?

**Technically yes**, but you're smart to upgrade first because:
- etcd will grow over time
- shuttle has less headroom
- Control-plane services will increase memory pressure
- Better to do it right once than struggle later

---

## Post-Upgrade Checklist

After upgrades, before HA migration:

- [ ] Verify nodes rejoined cluster
- [ ] Check all pods running
- [ ] Verify Longhorn volumes still accessible
- [ ] Run system updates (while you're at it)
- [ ] Test node stability under load
- [ ] Run `check-ha-status.sh` to verify baseline

---

## Alternative: Upgrade During Migration

You could also:
1. Upgrade shuttle and hp hardware
2. Join them as control-planes with fresh K3s install
3. They'll sync state from existing master via etcd

This might be cleaner since they'll be "fresh" control-plane nodes.

---

## LVM Expansion Quick Reference

If shuttle has free space in the volume group:

```bash
# Check free space
sudo vgs ubuntu-vg

# If "VFree" shows available space, expand:
sudo lvextend -L +20G /dev/ubuntu-vg/ubuntu-lv  # Add 20GB
# OR
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv  # Use all free

# Resize filesystem
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv

# Verify
df -h /
```

If no free space in VG, you need to add a physical disk or replace existing.

---

## Timeline

| Task | Duration |
|------|----------|
| Check LVM expansion options | 10 min |
| Expand LVM (if possible) | 5 min |
| Physical disk upgrade | 1-2 hours |
| Memory upgrade | 30 min |
| Verification | 15 min |

**Total**: 30 min (LVM only) to 3 hours (full hardware upgrade)

---

## Ready for HA Migration After Upgrades?

Once upgrades complete:
1. Verify resources: `ssh sgorey@192.168.1.12 "df -h / && free -h"`
2. Check cluster health: `kubectl get nodes && kubectl get pods -A | grep -v Running`
3. Proceed with HA migration: `ha-migration-helper.sh`

---

**Smart move upgrading first! 👍**
