#!/bin/bash

set -e  # Stop on error
set -o pipefail  # Catch pipeline errors

# Functions
source ./functions/check_config_env.sh
source ./functions/check_files.sh

# Files
CONFIG_FILE="./config.env"
KUBE_VIP_API_YAML="./kube-vip-api.yaml"
KUBE_VIP_LB_YAML="./kube-vip-lb.yaml"
KUBECONFIG_FILE="/etc/rancher/k3s/k3s.yaml"

# Check Deployments & Config Env
check_deployment $KUBE_VIP_API_YAML $KUBE_VIP_LB_YAML
check_config_env $CONFIG_FILE

exit 1

# --- Install K3s on First Node ---
export INSTALL_K3S_EXEC="$INSTALL_K3S_FIRSTNODE"
export INSTALL_K3S_VERSION="$K3S_VERSION"
export K3S_TOKEN

echo "🚀 Installing K3s version $K3S_VERSION with options: $INSTALL_K3S_EXEC"
curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s -

echo "✅ K3s installed successfully!"

# --- Deploy kube-vip for Kubernetes API VIP ---
export K3S_API_IP
export VIP_INTERFACE

echo "🚀 Deploying kube-vip for Kubernetes API at $K3S_API_IP on interface $VIP_INTERFACE"
envsubst < "$KUBE_VIP_API_YAML" | kubectl apply -f -
echo "✅ kube-vip for Kubernetes API deployed!"

# --- Optionally Deploy kube-vip for LoadBalancer Services ---
export VIP_LB_RANGE
export DEPLOY_LB_KUBEVIP
export VIP_INTERFACE

if [ "$DEPLOY_LB_KUBEVIP" == "true" ]; then
    echo "🚀 Deploying kube-vip for LoadBalancer Services with range $VIP_LB_RANGE on interface $VIP_INTERFACE"
    envsubst < "$KUBE_VIP_LB_YAML" | kubectl apply -f -
    echo "✅ kube-vip for LoadBalancer Services deployed!"
    echo "🎉 All done! Kubernetes API and optional LoadBalancer kube-vip are ready!"
else
    echo "⚙️ Skipping kube-vip LoadBalancer deployment as per config."
    echo "🎉 All done! Kubernetes API kube-vip are ready!"
fi

# --- Add API IP in Kubeconfig ---
check_kubeconfig $KUBECONFIG_FILE

echo "🔧 Replacing 127.0.0.1 with ${K3S_API_IP} in $KUBECONFIG_FILE"
sed -i "s/127.0.0.1/${K3S_API_IP}/g" "$KUBECONFIG_FILE"
echo "✅ K3s kubeconfig updated to use ${K3S_API_IP}"

# --- Add further Master Nodes ---

if [ "$HA_CLUSTER" == "true" ]; then
    IFS=',' read -r -a MASTER_NODES <<< "$MASTERS"
    export SSH_USER
    export SSH_KEY

    for master in "${MASTER_NODES[@]}"; do
        echo "🚀 Installing K3s version $K3S_VERSION on $master and adding it to the K3s Cluster"
        ssh -i "$SSH_KEY" "$SSH_USER@$master" << EOF
curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s - server --server https://$K3S_API_IP:6443 --write-kubeconfig-mode 644
EOF
        echo "✅ K3s installed and $master is added to K3s Cluster!"
    done
elif [ "$HA_CLUSTER" == "false" ]; then
    echo "✅ K3S installed as a Single Node"
else
    echo "Please Check HA_CLUSTER Parameter, actual value is: $HA_CLUSTER"
    exit 1
fi

# --- Adding WORKER Nodes ---

if [ "$ADDITIONAL_WORKERS" == "true" ]; then
    IFS=',' read -r -a WORKER_NODES <<< "$WORKERS"
    export SSH_USER
    export SSH_KEY

    for worker in "${WORKER_NODES[@]}"; do
        echo "🚀 Installing K3s version $K3S_VERSION on $worker and adding it to the K3s Cluster"
        ssh -i "$SSH_KEY" "$SSH_USER@$worker" << EOF
curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN K3S_URL=https://$K3S_API_IP:6443 sh -
EOF
        echo "✅ Worker Node $worker is added to K3s Cluster!"
    done
elif [ "$ADDITIONAL_WORKERS" == "false" ]; then
    echo "✅ No Worker Nodes added to the Cluster"
else
    echo "Please Check ADDITIONAL_WORKERS Parameter, actual value is: $ADDITIONAL_WORKERS"
    exit 1
fi

# --- Remove k3s-install user ---
