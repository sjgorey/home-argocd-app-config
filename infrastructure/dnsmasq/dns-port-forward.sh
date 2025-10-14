#!/bin/bash
# Port forwarding script to redirect standard DNS port 53 to NodePort 30053
# Run this on each x86_64 cluster node that you want to use as DNS servers

set -e

NODE_IP=${1:-$(hostname -I | awk '{print $1}')}
ACTION=${2:-"setup"}

setup_port_forwarding() {
    echo "Setting up DNS port forwarding on $NODE_IP..."
    
    # Add iptables rules to forward port 53 to 30053
    sudo iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 30053
    sudo iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 30053
    
    # Allow the traffic through
    sudo iptables -A INPUT -p tcp --dport 30053 -j ACCEPT
    sudo iptables -A INPUT -p udp --dport 30053 -j ACCEPT
    
    echo "Port forwarding rules added!"
    echo "DNS queries to $NODE_IP:53 will now be forwarded to the cluster DNS service."
}

remove_port_forwarding() {
    echo "Removing DNS port forwarding rules..."
    
    # Remove the forwarding rules
    sudo iptables -t nat -D PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 30053 2>/dev/null || true
    sudo iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 30053 2>/dev/null || true
    
    # Remove the input rules
    sudo iptables -D INPUT -p tcp --dport 30053 -j ACCEPT 2>/dev/null || true
    sudo iptables -D INPUT -p udp --dport 30053 -j ACCEPT 2>/dev/null || true
    
    echo "Port forwarding rules removed!"
}

show_status() {
    echo "Current iptables NAT rules for port 53:"
    sudo iptables -t nat -L PREROUTING -n | grep ":53"
    
    echo ""
    echo "Testing DNS on port 53:"
    dig @$NODE_IP google.com +short +timeout=2 || echo "DNS on port 53 not responding"
    
    echo ""
    echo "Testing DNS on port 30053:"
    dig @$NODE_IP -p 30053 google.com +short +timeout=2 || echo "DNS on port 30053 not responding"
}

case "$ACTION" in
    setup|install)
        setup_port_forwarding
        ;;
    remove|uninstall)
        remove_port_forwarding
        ;;
    status|test)
        show_status
        ;;
    *)
        echo "Usage: $0 [NODE_IP] [setup|remove|status]"
        echo ""
        echo "Examples:"
        echo "  $0 setup                    # Setup on current node"
        echo "  $0 192.168.1.5 setup      # Setup on specific node"
        echo "  $0 status                  # Check current status"
        echo "  $0 remove                  # Remove port forwarding"
        exit 1
        ;;
esac