#!/bin/bash

set -e  # Stop on error
set -o pipefail  # Catch pipeline errors

# Files
CONFIG_FILE="./config.env"
KUBE_VIP_API_YAML="./kube-vip-api.yaml"
KUBE_VIP_LB_YAML="./kube-vip-lb.yaml"

# --- Load Configuration ---
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file '$CONFIG_FILE' not found!"
    exit 1
fi

source "$CONFIG_FILE"
echo "✅ Loaded configuration from $CONFIG_FILE"

# --- Validate Required Variables ---
if [ -z "$K3S_VERSION" ]; then
    echo "❌ K3S_VERSION is not set!"
    exit 1
fi

if [ -z "$K3S_TOKEN" ]; then
    echo "❌ K3S_TOKEN is not set!"
    exit 1
fi

if [ -z "$K3S_API_IP" ]; then
    echo "❌ K3S_API_IP is not set!"
    exit 1
fi

if [ -z "$VIP_INTERFACE" ]; then
    echo "❌ VIP_INTERFACE is not set!"
    exit 1
fi

if [ -z "$MASTERS" ]; then
    echo "❌ MASTERS is not set!"
    exit 1
fi

if [ -z "$WORKERS" ]; then
    echo "⚠️ WORKERS is empty, continuing without workers..."
fi

# --- Parse master/worker IPs ---
IFS=',' read -r -a MASTER_NODES <<< "$MASTERS"
IFS=',' read -r -a WORKER_NODES <<< "$WORKERS"

# --- K3s Token ---
if [ -z "$K3S_TOKEN" ]; then
    K3S_TOKEN=$(openssl rand -hex 20)
    echo "🔑 Auto-generated K3S_TOKEN: $K3S_TOKEN"
fi

# --- Install K3s Functions ---
install_master() {
    echo "🚀 Installing K3s version $K3S_VERSION with options: $INSTALL_K3S_EXEC"
    curl -sfL https://get.k3s.io | sh -
}

join_master() {
  local node_ip=$1
  local first_master_ip=$2
  echo "🔗 Joining K3s master $node_ip to cluster via $first_master_ip"

  ssh -i "$SSH_KEY" "$SSH_USER@$node_ip" << EOF
curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN K3S_NODE_NAME=$node_ip INSTALL_K3S_VERSION=$K3S_VERSION sh -s - server --server https://$first_master_ip:6443 --tls-san $K3S_API_IP --node-taint CriticalAddonsOnly=true:NoExecute
EOF
}

install_worker() {
  local node_ip=$1
  local master_ip=$2
  echo "👷 Installing K3s worker on $node_ip"

  ssh -i "$SSH_KEY" "$SSH_USER@$node_ip" << EOF
curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN K3S_NODE_NAME=$node_ip INSTALL_K3S_VERSION=$K3S_VERSION K3S_URL=https://$master_ip:6443 sh -
EOF
}

# --- Install K3s Masters ---
FIRST_MASTER="${MASTER_NODES[0]}"
echo "🏁 Bootstrapping first master node: $FIRST_MASTER"
install_master

# Wait a bit to ensure first master is ready
sleep 20

# --- Fetch kubeconfig and token if dynamic token needed ---
# Optional step: if K3S_TOKEN was not predefined, pull it dynamically
# K3S_TOKEN=$(ssh -i "$SSH_KEY" "$SSH_USER@$FIRST_MASTER" "sudo cat /var/lib/rancher/k3s/server/node-token")

# --- Join additional masters ---
if [ "${#MASTER_NODES[@]}" -gt 1 ]; then
  for master_ip in "${MASTER_NODES[@]:1}"; do
    join_master "$master_ip" "$FIRST_MASTER"
  done
fi

# --- Install Workers ---
if [ -z "$WORKERS" ]; then
    echo "⚠️ WORKERS is empty, continuing without workers..."
else
    for worker_ip in "${WORKER_NODES[@]}"; do
        install_worker "$worker_ip" "$FIRST_MASTER"
    done
fi

# --- Deploy kube-vip for Kubernetes API VIP ---
if [ ! -f "$KUBE_VIP_API_YAML" ]; then
    echo "❌ kube-vip API YAML file '$KUBE_VIP_API_YAML' not found!"
    exit 1
fi

echo "🚀 Deploying kube-vip for Kubernetes API on $FIRST_MASTER"
export K3S_API_IP
export VIP_INTERFACE

ssh -i "$SSH_KEY" "$SSH_USER@$FIRST_MASTER" "kubectl apply -f -" < <(envsubst < "$KUBE_VIP_API_YAML")
echo "✅ kube-vip for Kubernetes API deployed!"

# --- Fix kubeconfig ---
KUBECONFIG_FILE="/etc/rancher/k3s/k3s.yaml"
LOCAL_KUBECONFIG="./k3s-kubeconfig.yaml"

echo "📥 Downloading kubeconfig from $FIRST_MASTER"
scp -i "$SSH_KEY" "$SSH_USER@$FIRST_MASTER:$KUBECONFIG_FILE" "$LOCAL_KUBECONFIG"

echo "🔧 Replacing 127.0.0.1 with ${K3S_API_IP} in $LOCAL_KUBECONFIG"
sed -i "s/127.0.0.1/${K3S_API_IP}/g" "$LOCAL_KUBECONFIG"

echo "✅ K3s kubeconfig updated and saved to $LOCAL_KUBECONFIG"

echo "🎉 All done! K3s HA cluster is ready!"

# --- Optionally Deploy kube-vip for LoadBalancer Services ---
if [ "$DEPLOY_LB_KUBEVIP" == "true" ]; then
    if [ ! -f "$KUBE_VIP_LB_YAML" ]; then
        echo "❌ kube-vip LB YAML file '$KUBE_VIP_LB_YAML' not found!"
        exit 1
    fi

    export VIP_LB_RANGE

    echo "🚀 Deploying kube-vip for LoadBalancer Services on $FIRST_MASTER with range $VIP_LB_RANGE"

    ssh -i "$SSH_KEY" "$SSH_USER@$FIRST_MASTER" "kubectl apply -f -" < <(envsubst < "$KUBE_VIP_LB_YAML")

    echo "✅ kube-vip for LoadBalancer Services deployed!"
else
    echo "⚙️ Skipping kube-vip LoadBalancer deployment as per config."
fi