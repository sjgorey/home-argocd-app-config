# dnsmasq High-Availability DNS Server

This directory contains a high-availability dnsmasq deployment for Kubernetes with LAN access and persistence.

## Features

- **High Availability**: 3 replicas with anti-affinity across nodes (currently 2 running on x86_64 nodes)
- **Architecture Compatibility**: Uses jpillora/dnsmasq image which runs on x86_64 nodes only
- **Persistent Cache**: Uses emptyDir volumes (previous Longhorn PVC had mounting issues)
- **LAN Access**: Multiple service types for flexible access
- **Health Checks**: Liveness and readiness probes
- **Network Security**: NetworkPolicy for controlled access
- **Wildcard DNS**: Pre-configured with wildcard *.example.com resolution

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   dnsmasq-1     │    │   dnsmasq-2     │    │   dnsmasq-3     │
│ (thinkpad x86)  │    │ (shuttle x86)   │    │ (odroid ARM)    │
│    RUNNING      │    │    RUNNING      │    │  CRASH LOOP     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       ╳
         └───────────────────────┼───────────────────────┘
                                 │
         ┌───────────────────────┴───────────────────────┐
         │                Services                       │
         │  • LoadBalancer: 192.168.1.12:53            │
         │  • NodePort: <any-node>:30053                │
         │  • ClusterIP: Internal cluster access        │
         └───────────────────────────────────────────────┘
```

**Current Status**: 2/3 pods running successfully on x86_64 nodes. The ARM-based Odroid pod fails due to architecture incompatibility with the jpillora/dnsmasq image.

## Router DNS Configuration

### Quick Setup for Standard Port 53

Since most routers only support standard DNS port 53, use the included port forwarding script:

#### 1. Copy Scripts to Nodes
```bash
# Copy the setup and test scripts to your stable x86_64 nodes
scp infrastructure/dnsmasq/dns-port-forward.sh sgorey@192.168.1.5:/tmp/
scp infrastructure/dnsmasq/test-dns-forwarding.sh sgorey@192.168.1.5:/tmp/

# Repeat for other nodes
scp infrastructure/dnsmasq/dns-port-forward.sh sgorey@192.168.1.12:/tmp/
scp infrastructure/dnsmasq/dns-port-forward.sh sgorey@192.168.1.6:/tmp/
```

#### 2. Setup Port Forwarding
```bash
# SSH to each node and setup port forwarding
ssh sgorey@192.168.1.5
sudo /tmp/dns-port-forward.sh setup

# Test the setup
sudo /tmp/test-dns-forwarding.sh
```

#### 3. Configure Your Router
Once testing passes, configure your router DNS servers:
- **Primary DNS**: `192.168.1.5`
- **Secondary DNS**: `192.168.1.12`
- **Tertiary DNS**: `192.168.1.6` (optional)

### Alternative: NodePort with Custom Port
If your router supports custom DNS ports, you can skip the port forwarding and use:
- **Primary**: `192.168.1.5:30053`
- **Secondary**: `192.168.1.12:30053`
- **Tertiary**: `192.168.1.6:30053`

## Configuration

### DNS Settings
The dnsmasq configuration includes:

- **Cache Size**: 1000 entries
- **Upstream DNS**: Google (8.8.8.8, 8.8.4.4) and Cloudflare (1.1.1.1, 1.0.0.1)
- **Local Domain**: `home.local`
- **Wildcard DNS**: `*.example.com` resolves to cluster nodes (192.168.1.5, 192.168.1.21-24)
- **Image**: `jpillora/dnsmasq:latest` (x86_64 architecture only)

### Custom DNS Entries
Edit `configmap.yaml` to add your local DNS entries:

```conf
# Custom local DNS entries
address=/router.home.local/192.168.1.1
address=/nas.home.local/192.168.1.100
address=/printer.home.local/192.168.1.200

# Wildcard for cluster services (already configured)
address=/example.com/192.168.1.5
address=/example.com/192.168.1.21
address=/example.com/192.168.1.22
address=/example.com/192.168.1.23
address=/example.com/192.168.1.24
```

### Resource Usage
Each dnsmasq pod uses:
- **CPU**: 50m request, 100m limit
- **Memory**: 64Mi request, 128Mi limit
- **Storage**: emptyDir volumes (local to each pod)
- **Architecture**: x86_64 only (ARM nodes will experience CrashLoopBackOff)

## Deployment

The dnsmasq service will be automatically deployed by ArgoCD when the configuration is pushed to the repository.

### Manual Commands (if needed)
```bash
# Apply all resources
kubectl apply -f infrastructure/dnsmasq/

# Check pod status
kubectl get pods -l app=dnsmasq

# Check services
kubectl get svc -l app=dnsmasq

# View logs
kubectl logs -l app=dnsmasq -f

# Test DNS resolution
kubectl run -it --rm dns-test --image=busybox --restart=Never -- nslookup google.com dnsmasq.default.svc.cluster.local
```

## Testing

### From LAN devices
```bash
# Test with standard port 53 (after port forwarding setup)
nslookup google.com 192.168.1.5
dig @192.168.1.5 prometheus.example.com

# Test with NodePort (works without port forwarding)
nslookup google.com 192.168.1.5:30053
dig @192.168.1.5 -p 30053 grafana.example.com

# Test wildcard resolution
nslookup argocd.example.com 192.168.1.5
nslookup grafana.example.com 192.168.1.12
```

### Testing Port Forwarding
```bash
# After setting up port forwarding on a node, test it:
ssh sgorey@192.168.1.5
sudo /tmp/test-dns-forwarding.sh

# This will verify:
# ✅ iptables rules are in place
# ✅ NodePort 30053 responds
# ✅ Port 53 forwarding works
# ✅ Wildcard DNS resolves correctly
```
```

### From cluster
```bash
# Test internal resolution
kubectl run -it --rm dns-test --image=busybox --restart=Never -- nslookup google.com dnsmasq
```

## Monitoring

Check dnsmasq status:
```bash
# Pod health
kubectl get pods -l app=dnsmasq -o wide

# Service endpoints
kubectl get endpoints dnsmasq

# View configuration
kubectl get configmap dnsmasq-config -o yaml

# Check logs for queries
kubectl logs -l app=dnsmasq | grep query
```

## High Availability Features

1. **Multiple Replicas**: 3 pods spread across different nodes (2 running on x86_64)
2. **Anti-Affinity**: Ensures pods don't run on the same node
3. **Rolling Updates**: Updates happen one pod at a time
4. **Health Checks**: Automatic restart of failing pods
5. **Individual Cache**: Each pod maintains its own cache (emptyDir)
6. **Multiple Access Methods**: LoadBalancer + NodePort for redundancy
7. **Architecture Awareness**: Currently optimized for x86_64 nodes

## Customization

1. **Replica Count**: Adjust `replicas` in `deployment.yaml`
2. **DNS Forwarders**: Modify upstream servers in `configmap.yaml`
3. **LoadBalancer IP**: Change `loadBalancerIP` in `service.yaml`
4. **Local DNS Entries**: Add custom addresses in `configmap.yaml`
5. **Resource Limits**: Adjust CPU/memory in `deployment.yaml`

## Troubleshooting

### Common Issues

1. **LoadBalancer Pending**: Install MetalLB or use NodePort
2. **DNS Resolution Fails**: Check upstream DNS servers
3. **Pod Crashes on ARM**: jpillora/dnsmasq only supports x86_64 architecture
4. **Cache Issues**: Restart pods to clear individual caches
5. **Partial Deployment**: 2/3 pods running is normal due to ARM incompatibility

### Useful Commands
```bash
# Check current DNS settings
kubectl exec -it deployment/dnsmasq -- cat /etc/resolv.conf

# Test specific DNS query
kubectl exec -it deployment/dnsmasq -- nslookup google.com 127.0.0.1

# Check dnsmasq process
kubectl exec -it deployment/dnsmasq -- ps aux | grep dnsmasq

# View real-time logs
kubectl logs -l app=dnsmasq -f --tail=100
```