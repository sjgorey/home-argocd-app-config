## ssh to each node and run:

sudo apt install -y dnsutils
# 1. Kill systemd-resolved and make sure it stays dead
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# 2. Remove the immutable flag that’s blocking us
sudo chattr -i /etc/resolv.conf 2>/dev/null || true

# 3. Write the correct resolv.conf
sudo sh -c 'echo "nameserver 10.43.255.253" > /etc/resolv.conf'

# 4. Install the absolute simplest possible unit that cannot fail
sudo tee /etc/systemd/system/k3s-node-dns.service > /dev/null <<'EOF'
[Unit]
Description=Force node to use in-cluster Unbound
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c "echo 'nameserver 10.43.255.253' > /etc/resolv.conf"
EOF

# 5. Enable it
sudo systemctl daemon-reload
sudo systemctl enable --now k3s-node-dns.service

dig node21.home.local +short

