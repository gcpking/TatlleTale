#!/bin/bash
# Generate a WireGuard client config and QR code
# Usage: sudo bash gen-client.sh <client-name>
# Example: sudo bash gen-client.sh laptop

set -euo pipefail

CLIENT_NAME="${1:?Usage: $0 <client-name>}"
SERVER_CONF="/etc/wireguard/wg0.conf"
CLIENTS_DIR="/etc/wireguard/clients"
mkdir -p "$CLIENTS_DIR"

# Read server pubkey
SERVER_PRIVKEY=$(grep '^PrivateKey' "$SERVER_CONF" | awk '{print $3}')
SERVER_PUBKEY=$(echo "$SERVER_PRIVKEY" | wg pubkey)

# Detect server's public IP
SERVER_IP=$(curl -s https://api.ipify.org)

# Assign the next available IP in 10.0.0.0/24
USED=$(grep -oP '10\.0\.0\.\K\d+' "$SERVER_CONF" || true)
NEXT=2
while echo "$USED" | grep -qw "$NEXT"; do
  NEXT=$((NEXT + 1))
done
CLIENT_IP="10.0.0.$NEXT"

# Generate client keys
CLIENT_PRIVKEY=$(wg genkey)
CLIENT_PUBKEY=$(echo "$CLIENT_PRIVKEY" | wg pubkey)
PRESHARED_KEY=$(wg genpsk)

# Write client config file
CLIENT_CONF="$CLIENTS_DIR/$CLIENT_NAME.conf"
cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address    = $CLIENT_IP/24
DNS        = 1.1.1.1

[Peer]
PublicKey    = $SERVER_PUBKEY
PresharedKey = $PRESHARED_KEY
Endpoint     = $SERVER_IP:51820
AllowedIPs   = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENT_CONF"

# Add peer to server config (no restart needed — wg addconf is hot-reload)
cat >> "$SERVER_CONF" <<EOF

[Peer]
# $CLIENT_NAME
PublicKey    = $CLIENT_PUBKEY
PresharedKey = $PRESHARED_KEY
AllowedIPs   = $CLIENT_IP/32
EOF

wg addconf wg0 <(grep -A4 "# $CLIENT_NAME" "$SERVER_CONF") 2>/dev/null || wg syncconf wg0 <(wg-quick strip wg0)

echo ""
echo "=== Client config: $CLIENT_NAME ($CLIENT_IP) ==="
cat "$CLIENT_CONF"
echo ""
echo "=== QR Code (scan with mobile WireGuard app) ==="
qrencode -t ansiutf8 < "$CLIENT_CONF"
echo ""
echo "Config saved to: $CLIENT_CONF"
