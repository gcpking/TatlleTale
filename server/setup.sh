#!/bin/bash
# WireGuard server setup for Ubuntu 22.04 — Oracle Cloud Free Tier (US East, Ashburn)
# Run as root: sudo bash setup.sh

set -euo pipefail

echo "=== TattleTale VPN — WireGuard Server Setup ==="

# 1. Update and install WireGuard
apt-get update -y
apt-get install -y wireguard wireguard-tools qrencode ufw

# 2. Enable IP forwarding
cat > /etc/sysctl.d/99-wireguard.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl --system

# 3. Generate server keys
SERVER_PRIVKEY=$(wg genkey)
SERVER_PUBKEY=$(echo "$SERVER_PRIVKEY" | wg pubkey)

echo ""
echo "Server private key: $SERVER_PRIVKEY"
echo "Server public key:  $SERVER_PUBKEY"
echo ""

# 4. Detect default network interface (usually ens3 on Oracle Cloud)
DEFAULT_IFACE=$(ip route | awk '/^default/ {print $5; exit}')
echo "Detected network interface: $DEFAULT_IFACE"

# 5. Write server config
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIVKEY
DNS = 1.1.1.1

# NAT — forward VPN traffic through the server's internet connection
PostUp   = ufw route allow in on wg0 out on $DEFAULT_IFACE
PostUp   = iptables -t nat -A POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE
PostDown = ufw route delete allow in on wg0 out on $DEFAULT_IFACE
PostDown = iptables -t nat -D POSTROUTING -o $DEFAULT_IFACE -j MASQUERADE

# No logging — WireGuard is silent by design; we add nothing
EOF

chmod 600 /etc/wireguard/wg0.conf

echo "Server config written to /etc/wireguard/wg0.conf"

# 6. Firewall rules
ufw allow 22/tcp   comment 'SSH'
ufw allow 51820/udp comment 'WireGuard'
ufw --force enable
echo "UFW rules applied"

# 7. Enable and start WireGuard
systemctl enable wg-quick@wg0
systemctl start  wg-quick@wg0

echo ""
echo "=== WireGuard server is running ==="
echo "Server public key: $SERVER_PUBKEY"
echo "Next: run  ./gen-client.sh <client-name>  to create a peer config"
