# Unbound DNS Server

High-availability DNS server running in Kubernetes, providing:

- External DNS resolution (forwards to 8.8.8.8, 8.8.4.4, 1.1.1.1, 1.0.0.1)
- Wildcard DNS for `*.example.com` → cluster nodes 
- Local domain resolution for `*.home.local`

## Services

- **Primary LoadBalancer**: `192.168.1.12:53` (for router configuration)
- **NodePort**: All nodes on port `30053` 
- **ClusterIP**: Internal cluster access

## Files

- `deployment.yaml` - Unbound deployment (x86_64 nodes only)
- `service.yaml` - ClusterIP, LoadBalancer, and NodePort services
- `configmap.yaml` - Unbound configuration
- `dns-port-forward.sh` - Script for port 53→30053 forwarding (if needed)
- `test-dns-forwarding.sh` - Testing utilities

## Usage

Configure your router to use `192.168.1.12` as the primary DNS server.

All `*.example.com` domains will resolve to cluster nodes for ingress access.

## Testing

```bash
# Test external DNS
dig @192.168.1.12 google.com

# Test wildcard DNS  
dig @192.168.1.12 dashboard.example.com

# Test via NodePort
dig @192.168.1.5 -p 30053 google.com
```

## Architecture

Currently running 2 Unbound pods on x86_64 nodes (thinkpad and shuttle). All 7 cluster nodes can serve DNS via MetalLB LoadBalancer routing.

- **Active Pods**: 192.168.1.6 (hp) and 192.168.1.12 (shuttle)
- **LoadBalancer IPs**: All cluster nodes (192.168.1.5, 1.6, 1.12, 1.21-1.24)
- **Primary Access**: 192.168.1.12:53

## Configuration

The Unbound service provides:
- Recursive DNS resolution with upstream forwarders
- Wildcard DNS: `*.example.com` → 192.168.1.5
- Local domain: `*.home.local`
- DNSSEC validation
- Access control allowing queries from any source