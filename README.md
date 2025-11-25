# home-cluster

Information on running k3s and ArgoCD on home cluster

## Cluster Architecture

### High Availability Setup
- **Control Plane Nodes** (3): thinkpad-192-168-1-5, shuttle-192-168-1-12, hp-192-168-1-6
  - Running K3s server with embedded etcd (HA quorum: 2/3)
  - Automatic API failover during node reboots
  - Zero-downtime maintenance capability
  
- **Worker Nodes** (4): odroid1-4 (ARM64)
  - Running K3s agent
  - Mixed architecture support (AMD64 + ARM64)

### Storage
- **Longhorn**: Distributed block storage across all nodes
- **26 Persistent Volumes** serving applications
- Automatic replication and failover

### Key Components
- **ArgoCD**: GitOps continuous delivery
- **Prometheus + Grafana**: Monitoring and alerting
- **Loki**: Log aggregation
- **Traefik**: Ingress controller
- **Kafka**: Event streaming (3 brokers + 3 controllers)

---

## Setup K3s

See https://k3s.io/ for official documentation.

### Initial Setup (Single Node - Legacy)

**Note**: For HA setup, see [HA Migration Guide](docs/K3S-HA-MIGRATION-PLAN.md)

#### Run this on the master
```bash
curl -sfL https://get.k3s.io | sh -
```

#### Get the master node token
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

#### Run following on all the agents
```bash
sudo k3s agent --server https://{MASTER}:6443 --token ${NODE_TOKEN}
```

### High Availability Setup (Current)

**See detailed guides**:
- 📖 [Complete HA Migration Plan](docs/K3S-HA-MIGRATION-PLAN.md) - Full documentation with troubleshooting
- ✅ [Migration Checklist](docs/HA-MIGRATION-CHECKLIST.md) - Step-by-step with checkboxes  
- 🚀 [Quick Start Guide](docs/HA-QUICK-START.md) - Fast copy-paste version

**TL;DR**: 3-node embedded etcd cluster for zero-downtime master reboots

#### Initialize first control-plane node
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable=servicelb \
  --write-kubeconfig-mode=644
```

#### Join additional control-plane nodes
```bash
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://{MASTER_IP}:6443 \
  --token ${K3S_TOKEN} \
  --disable=servicelb \
  --write-kubeconfig-mode=644
```

#### Verify HA setup
```bash
kubectl get nodes  # Should show 3 control-plane nodes
kubectl get pods -n kube-system | grep etcd  # Should show 3 etcd pods
```

## setup ArcgoCD

https://argo-cd.readthedocs.io/en/stable/getting_started/

### create namespace
kubectl create namespace argocd

### install argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

### switch service to loadbalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'


### add port forarding so we can access UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
