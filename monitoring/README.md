helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack



helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install loki grafana/loki-stack --set fluent-bit.enabled=true
