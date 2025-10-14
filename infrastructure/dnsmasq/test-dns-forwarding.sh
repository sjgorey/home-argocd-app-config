#!/bin/bash
# Test script for DNS port forwarding
# 
# To use this script:
# 1. Copy to node: scp test-dns-forwarding.sh sgorey@192.168.1.5:/tmp/
# 2. SSH to node: ssh sgorey@192.168.1.5
# 3. Run test: sudo /tmp/test-dns-forwarding.sh
#
# Run this on the node where you set up port forwarding

NODE_IP=${1:-$(hostname -I | awk '{print $1}')}

echo "=== DNS Port Forwarding Test for $NODE_IP ==="
echo ""

echo "1. Checking iptables NAT rules..."
if sudo iptables -t nat -L PREROUTING -n | grep -q ":53"; then
    echo "✅ Port 53 forwarding rules found:"
    sudo iptables -t nat -L PREROUTING -n | grep ":53"
else
    echo "❌ No port 53 forwarding rules found!"
    echo "Run: sudo ./dns-port-forward.sh setup"
fi

echo ""
echo "2. Testing NodePort 30053 (should work)..."
if timeout 3 dig @127.0.0.1 -p 30053 google.com +short >/dev/null 2>&1; then
    echo "✅ NodePort 30053 is responding"
    echo "Response: $(dig @127.0.0.1 -p 30053 google.com +short | head -1)"
else
    echo "❌ NodePort 30053 not responding"
fi

echo ""
echo "3. Testing standard port 53 (with forwarding)..."
if timeout 3 dig @127.0.0.1 google.com +short >/dev/null 2>&1; then
    echo "✅ Port 53 is responding via forwarding"
    echo "Response: $(dig @127.0.0.1 google.com +short | head -1)"
else
    echo "❌ Port 53 not responding"
fi

echo ""
echo "4. Testing wildcard DNS..."
if timeout 3 dig @127.0.0.1 -p 30053 prometheus.example.com +short >/dev/null 2>&1; then
    echo "✅ Wildcard DNS working:"
    echo "prometheus.example.com -> $(dig @127.0.0.1 -p 30053 prometheus.example.com +short)"
else
    echo "❌ Wildcard DNS not working"
fi

echo ""
echo "5. Checking for port conflicts..."
echo "Services using port 53:"
sudo netstat -tulnp 2>/dev/null | grep ":53" || sudo ss -tulnp 2>/dev/null | grep ":53" || echo "No services found on port 53"

echo ""
echo "=== Summary ==="
echo "If all tests pass, you can configure your router to use $NODE_IP as DNS server"