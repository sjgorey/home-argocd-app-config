## ssh to each node and run:

sudo apt install -y dnsutils
# 1. Kill systemd-resolved and make sure it stays dead
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# 2. Remove the immutable flag that’s blocking us
sudo chattr -i /etc/resolv.conf 2>/dev/null || true

# 3. Write resolv.conf: Unbound VIP first, public resolver fallback
#    (fallback avoids chicken-and-egg when unbound is down during node/image recovery)
sudo sh -c "printf 'nameserver 192.168.1.241\nnameserver 8.8.8.8\n' > /etc/resolv.conf"

# 4. Persist across reboot
sudo tee /etc/systemd/system/k3s-node-dns.service > /dev/null <<'EOF'
[Unit]
Description=Force node DNS to Unbound VIP with public fallback
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c "printf 'nameserver 192.168.1.241\\nnameserver 8.8.8.8\\n' > /etc/resolv.conf"

[Install]
WantedBy=multi-user.target
EOF

# 5. Enable it
sudo systemctl daemon-reload
sudo systemctl enable --now k3s-node-dns.service

dig @192.168.1.241 google.com +short
dig node21.home.local +short
