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

https://argo-cd.readthedocs.io/en/stable/getting_started/

### create namespace
kubectl create namespace argocd

### install argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

### switch service to loadbalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'


### add port forarding so we can access UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
