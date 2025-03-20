#!/bin/bash
set -e

install_additional_master_node(){

    ORIGINAL_KUBECONFIG=$1
    HA_KUBECONFIG=$2
    API_IP=$3
    NEW_URL="https://$API_IP:6443"

    if [ -z "$MASTERS" ]; then
        echo "❌ MASTERS is not set!"
        exit 1
    fi

    if [ -z "$ADD_K3S_MASTER" ]; then
        echo "❌ K3S_TOKEN is not set!"
        exit 1
    fi

    if [ -z "$K3S_API_IP" ]; then
        echo "❌ K3S_API_IP is not set!"
        exit 1
    fi

    export K3S_TOKEN

    if [ "$HA_CLUSTER" == "true" ]; then
    IFS=',' read -r -a MASTER_NODES <<< "$MASTERS"
    
    for master in "${MASTER_NODES[@]}"; do
        echo "🚀 Installing K3s version $K3S_VERSION on $master and adding it to the K3s Cluster"
        ssh -i "$SSH_KEY" "$SSH_USER@$master" << EOF
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
export KUBECONFIG="$HA_KUBECONFIG"

echo "✅ New KUBECONFIG set to $HA_KUBECONFIG on $master"
EOF
        echo "✅ K3s installed, KUBECONFIG chenged and $master is added to K3s Cluster!"
    done
    elif [ "$HA_CLUSTER" == "false" ]; then
        echo "✅ K3S installed as a Single Node"
    else
        echo "❌ Current value of HA_CLUSTER is not allowed: $HA_CLUSTER"
        exit 1
    fi

    unset $K3S_TOKEN

}