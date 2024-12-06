# home-cluster

information on running k3s and argocd on home cluster

## setup k3s
got to https://k3s.io/

### run this on the master
curl -sfL https://get.k3s.io | sh -

### get the master node token

sudo cat /var/lib/rancher/k3s/server/node-token

### run following on all the agents

sudo k3s agent --server https://{MASTER}:6443 --token ${NODE_TOKEN}

## setup ArcgoCD

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
