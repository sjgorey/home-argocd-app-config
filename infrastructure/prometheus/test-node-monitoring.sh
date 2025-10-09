#!/bin/bash

echo "🔍 K3s Node Monitoring - Quick Test Script"
echo "=========================================="

# Test 1: Check if PrometheusRule is active
echo "✅ Testing PrometheusRule deployment..."
RULE_COUNT=$(kubectl get prometheusrule k3s-node-alerts -n monitoring -o jsonpath='{.spec.groups[*].rules[*]}' | jq '. | length' 2>/dev/null || echo "0")
if [ "$RULE_COUNT" -gt "0" ]; then
    echo "   ✓ PrometheusRule 'k3s-node-alerts' found with rules"
else
    echo "   ❌ PrometheusRule not found or no rules"
fi

# Test 2: Check node-exporter is running on all nodes
echo ""
echo "✅ Testing node-exporter coverage..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
EXPORTER_COUNT=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=node-exporter --no-headers | wc -l)
echo "   Nodes: $NODE_COUNT, Node-exporters: $EXPORTER_COUNT"
if [ "$NODE_COUNT" -eq "$EXPORTER_COUNT" ]; then
    echo "   ✓ Node-exporter running on all nodes"
else
    echo "   ⚠️  Node-exporter coverage incomplete"
fi

# Test 3: Check if Prometheus can see our rules
echo ""
echo "✅ Testing Prometheus rule loading..."
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
PF_PID=$!
sleep 3

if curl -s "http://localhost:9090/api/v1/rules" | grep -q "k3s-node-health"; then
    echo "   ✓ Prometheus has loaded k3s-node-health rules"
else
    echo "   ❌ Prometheus hasn't loaded our rules yet"
fi

kill $PF_PID 2>/dev/null

# Test 4: Quick metrics availability test
echo ""
echo "✅ Testing metrics availability..."
kubectl run metric-test --image=curlimages/curl --rm -it --restart=Never --quiet -- \
  curl -s http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up{job=\"node-exporter\"} | \
  python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data['status'] == 'success' and len(data['data']['result']) > 0:
        up_nodes = sum(1 for r in data['data']['result'] if r['value'][1] == '1')
        total_nodes = len(data['data']['result'])
        print(f'   ✓ {up_nodes}/{total_nodes} nodes reporting metrics')
    else:
        print('   ❌ No node metrics found')
except:
    print('   ❌ Failed to query metrics')
" 2>/dev/null || echo "   ⚠️  Could not test metrics from inside cluster"

# Test 5: Dashboard availability
echo ""
echo "✅ Testing Grafana dashboard..."
if kubectl get configmap k3s-node-health-dashboard -n monitoring >/dev/null 2>&1; then
    echo "   ✓ Dashboard ConfigMap deployed"
    echo "   📊 Access: https://grafana.yourdomain.com/d/k3s-node-health"
else
    echo "   ❌ Dashboard ConfigMap not found"
fi

echo ""
echo "🧪 SIMPLE ALERT TEST"
echo "==================="
echo "To test if alerts actually fire, try:"
echo ""
echo "1. 💻 CPU stress test (triggers NodeHighCPUUsage):"
echo "   kubectl run cpu-stress --image=progrium/stress --rm -it --restart=Never -- --cpu 2 --timeout 300s"
echo ""
echo "2. 🧠 Memory stress test (triggers NodeHighMemoryUsage):"
echo "   kubectl run mem-stress --image=progrium/stress --rm -it --restart=Never -- --vm 1 --vm-bytes 512M --timeout 300s"
echo ""
echo "3. 📊 View alerts in real-time:"
echo "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "   Open: http://localhost:9090/alerts"
echo ""
echo "4. 🎛️  View AlertManager:"
echo "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
echo "   Open: http://localhost:9093"
echo ""
echo "⚡ Current Node Status:"
echo "======================"
kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory" 2>/dev/null || kubectl get nodes