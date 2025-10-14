# dnsmasq High-Availability DNS Server

This directory contains a high-availability dnsmasq deployment for Kubernetes with LAN access and persistence.

## Features

- **High Availability**: 3 replicas with anti-affinity across nodes
- **Persistence**: Shared cache storage using Longhorn
- **LAN Access**: Multiple service types for flexible access
- **Health Checks**: Liveness and readiness probes
- **Network Security**: NetworkPolicy for controlled access
- **Local DNS**: Pre-configured with cluster service addresses

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   dnsmasq-1     │    │   dnsmasq-2     │    │   dnsmasq-3     │
│   (node-1)      │    │   (node-2)      │    │   (node-3)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌───────────────────────┴───────────────────────┐
         │                Services                       │
         │  • LoadBalancer: 192.168.1.53:53            │
         │  • NodePort: <any-node>:30053                │
         │  • ClusterIP: Internal cluster access        │
         └───────────────────────────────────────────────┘
```

## Access Methods

### Primary (LoadBalancer)
- **IP**: `192.168.1.53:53`
- **Requires**: MetalLB or similar LoadBalancer implementation
- **Usage**: Configure LAN devices to use `192.168.1.53` as DNS

### Fallback (NodePort)
- **Ports**: `<any-node-ip>:30053`
- **Examples**: 
  - `192.168.1.5:30053` (thinkpad)
  - `192.168.1.21:30053` (odroid1)
  - `192.168.1.22:30053` (odroid2)
- **Usage**: Configure LAN devices with multiple DNS entries

### Internal (ClusterIP)
- **Service**: `dnsmasq.default.svc.cluster.local:53`
- **Usage**: For cluster-internal DNS resolution

## Configuration

### DNS Settings
The dnsmasq configuration includes:

- **Cache Size**: 1000 entries
- **Upstream DNS**: Google (8.8.8.8, 8.8.4.4) and Cloudflare (1.1.1.1, 1.0.0.1)
- **Local Domain**: `home.local`
- **Cluster Services**: Pre-configured addresses for ArgoCD, Grafana, etc.

### Custom DNS Entries
Edit `configmap.yaml` to add your local DNS entries:

```conf
# Custom local DNS entries
address=/router.home.local/192.168.1.1
address=/nas.home.local/192.168.1.100
address=/printer.home.local/192.168.1.200
```

### Resource Usage
Each dnsmasq pod uses:
- **CPU**: 50m request, 100m limit
- **Memory**: 64Mi request, 128Mi limit
- **Storage**: 1Gi shared cache (Longhorn)

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
# Test with NodePort
nslookup google.com 192.168.1.5:30053

# Test with LoadBalancer (if configured)
nslookup google.com 192.168.1.53

# Test local resolution
nslookup argocd.example.com 192.168.1.53
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

1. **Multiple Replicas**: 3 pods spread across different nodes
2. **Anti-Affinity**: Ensures pods don't run on the same node
3. **Rolling Updates**: Updates happen one pod at a time
4. **Health Checks**: Automatic restart of failing pods
5. **Shared Cache**: All pods share the same cache storage
6. **Multiple Access Methods**: LoadBalancer + NodePort for redundancy

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
3. **Pod Crashes**: Review resource limits and logs
4. **Cache Issues**: Restart pods to clear cache

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