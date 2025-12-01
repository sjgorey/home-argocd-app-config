sudo sed -i 's/10\.43\.[0-9.]*[0-9]/10.43.255.253/g' /etc/systemd/system/k3s-node-dns.service 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl restart k3s-node-dns.service
