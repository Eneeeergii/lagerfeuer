#!/bin/bash
set -e

CONFIG_FILE=/tmp/config.env
source "$CONFIG_FILE"
echo "✅ Loaded configuration from $CONFIG_FILE"

ORIGINAL_KUBECONFIG=$KUBECONFIG
HA_KUBECONFIG=$KUBECONFIG_HA
API_IP=$K3S_API_IP
NEW_URL="https://$API_IP:6443"

curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s - server --server https://$K3S_API_IP:6443 --write-kubeconfig-mode 644
if [ ! -f "$ORIGINAL_KUBECONFIG" ]; then
    echo "❌ Error: Original kubeconfig file not found at $ORIGINAL_KUBECONFIG"
    exit 1
fi

sudo cp "$ORIGINAL_KUBECONFIG" "$HA_KUBECONFIG"
sudo sed -i "s|https://127.0.0.1:6443|$NEW_URL|g" "$HA_KUBECONFIG"

if grep -q "$NEW_URL" "$HA_KUBECONFIG"; then
    echo "✅ Successfully updated server URL in $HA_KUBECONFIG on $master"
else
    echo "❌ Error: Failed to update server URL on $master"
    exit 1
fi

if grep -q "KUBECONFIG=" /etc/environment; then
    sudo sed -i "s|KUBECONFIG=.*|KUBECONFIG=$HA_KUBECONFIG|" /etc/environment
else
    echo "KUBECONFIG=$HA_KUBECONFIG" | sudo tee -a /etc/environment
fi

echo "✅ New KUBECONFIG set to $HA_KUBECONFIG on $master"