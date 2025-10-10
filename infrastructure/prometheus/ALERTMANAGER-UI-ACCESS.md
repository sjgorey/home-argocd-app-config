# 📊 Viewing AlertManager Configuration in Grafana

## ✅ **Multiple Ways to Access AlertManager in Grafana**

### **Method 1: Grafana Built-in Alerting (Recommended)**

1. **Open Grafana** → Click **"Alerting"** in the left sidebar
2. **View Sections:**
   - **🚨 Alert Rules** - See all your K3s node alert rules
   - **📬 Contact Points** - View email/Slack notification settings  
   - **🛣️ Notification Policies** - See alert routing configuration
   - **🔇 Silences** - Manage alert suppressions
   - **📊 Alert Groups** - View grouped alerts

### **Method 2: AlertManager Dashboard (Just Added)**

1. **Go to Dashboards** → **Browse**
2. **Look for**: "AlertManager Status"
3. **Features:**
   - Active alerts table
   - Firing alerts over time
   - Alerts by severity breakdown

### **Method 3: AlertManager Data Source (Just Configured)**

1. **Go to Explore** → Select **"AlertManager"** data source
2. **Query Options:**
   - View active alerts
   - Browse alert history
   - Check AlertManager API status

### **Method 4: Direct AlertManager UI Access**

```bash
# Port-forward to AlertManager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Open in browser: http://localhost:9093
```

**AlertManager UI Features:**
- **Status** - View configuration and runtime info
- **Alerts** - See all active and suppressed alerts  
- **Silences** - Create/manage alert silences
- **Config** - View current configuration (your email settings!)

---

## 🔍 **What You Can See in Each Interface**

### **Grafana Alerting Section:**
```
✅ All your K3s node alert rules (NodeDown, NodeCritical*, etc.)
✅ Email contact point configuration
✅ Alert routing policies (critical vs warning)
✅ Current alert status and history
```

### **Direct AlertManager UI:**
```
✅ Full YAML configuration display
✅ SMTP settings (your gorco@maine.rr.com config)
✅ Route trees and inhibition rules
✅ Active alerts with full details
✅ Silence management
```

### **Grafana AlertManager Dashboard:**
```
✅ Visual alert summary
✅ Trends and patterns
✅ Severity breakdown
✅ Alert state over time
```

---

## 🎯 **Quick Access Guide**

### **To View Your Email Configuration:**
1. **Option A**: AlertManager UI → **Status** → **Config**
2. **Option B**: Grafana → **Alerting** → **Contact Points**

### **To See Active K3s Node Alerts:**
1. **Option A**: Grafana → **Alerting** → **Alert Rules**
2. **Option B**: "AlertManager Status" dashboard
3. **Option C**: AlertManager UI → **Alerts**

### **To Test Alert Routing:**
1. **Create test alert** (CPU stress test)
2. **Watch in Grafana** → **Alerting** → **Alert Groups**
3. **Check email delivery**

---

## 🛠️ **Current Configuration Summary**

Your AlertManager is configured with:

**📧 Email Notifications:**
- **SMTP Server**: smtp-server.maine.rr.com
- **From Address**: gorco@maine.rr.com  
- **Recipients**: Configured for critical alerts

**🚨 Alert Routing:**
- **Critical alerts** (NodeDown, etc.) → Immediate email
- **Warning alerts** → Batched notifications
- **Inhibition rules** → Prevent alert storms

**🎯 Alert Categories:**
- **25+ K3s node health rules** active
- **Multi-severity routing** (critical/warning)
- **Smart suppression** (critical suppresses related warnings)

---

## 🔄 **After Grafana Restart**

Grafana is restarting to pick up the new AlertManager data source. Once ready:

1. **Check Data Sources**: Configuration → Data Sources → Look for "AlertManager"
2. **Find New Dashboard**: Browse → "AlertManager Status"  
3. **Verify Alerting**: Alerting section shows your K3s rules

**Restart Status**: Monitor with `kubectl get pods -n monitoring | grep grafana`

Your AlertManager configuration is now fully accessible through multiple Grafana interfaces! 🚀