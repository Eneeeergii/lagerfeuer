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

if [ -z "$K3S_API_IP" ]; then
    echo "❌ K3S_API_IP is not set!"
    exit 1
fi

if [ -z "$VIP_INTERFACE" ]; then
    echo "❌ VIP_INTERFACE is not set!"
    exit 1
fi

# Optional K3S_TOKEN check
if [ -n "$K3S_TOKEN" ]; then
    export K3S_TOKEN
    echo "🔑 K3S_TOKEN is set."
fi

# --- Install K3s ---
export INSTALL_K3S_EXEC
export INSTALL_K3S_VERSION="$K3S_VERSION"

echo "🚀 Installing K3s version $K3S_VERSION with options: $INSTALL_K3S_EXEC"
curl -sfL https://get.k3s.io | sh -

echo "✅ K3s installed successfully!"

# --- Fix kubeconfig ---
KUBECONFIG_FILE="/etc/rancher/k3s/k3s.yaml"

if [ -f "$KUBECONFIG_FILE" ]; then
    echo "🔧 Replacing 127.0.0.1 with ${K3S_API_IP} in $KUBECONFIG_FILE"
    sed -i "s/127.0.0.1/${K3S_API_IP}/g" "$KUBECONFIG_FILE"
    echo "✅ K3s kubeconfig updated to use ${K3S_API_IP}"
else
    echo "❌ K3s kubeconfig not found at $KUBECONFIG_FILE!"
    exit 1
fi

# Optional: copy kubeconfig to user home for kubectl access
mkdir -p $HOME/.kube
cp "$KUBECONFIG_FILE" $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
echo "✅ Kubeconfig copied to $HOME/.kube/config for kubectl access"

# --- Deploy kube-vip for Kubernetes API VIP ---
if [ ! -f "$KUBE_VIP_API_YAML" ]; then
    echo "❌ kube-vip API YAML file '$KUBE_VIP_API_YAML' not found!"
    exit 1
fi

export K3S_API_IP
export VIP_INTERFACE

echo "🚀 Deploying kube-vip for Kubernetes API at $K3S_API_IP on interface $VIP_INTERFACE"

envsubst < "$KUBE_VIP_API_YAML" | kubectl apply -f -

echo "✅ kube-vip for Kubernetes API deployed!"

# --- Optionally Deploy kube-vip for LoadBalancer Services ---
if [ "$DEPLOY_LB_KUBEVIP" == "true" ]; then
    if [ ! -f "$KUBE_VIP_LB_YAML" ]; then
        echo "❌ kube-vip LB YAML file '$KUBE_VIP_LB_YAML' not found!"
        exit 1
    fi

    export VIP_LB_RANGE

    echo "🚀 Deploying kube-vip for LoadBalancer Services with range $VIP_LB_RANGE on interface $VIP_INTERFACE"

    envsubst < "$KUBE_VIP_LB_YAML" | kubectl apply -f -

    echo "✅ kube-vip for LoadBalancer Services deployed!"
else
    echo "⚙️ Skipping kube-vip LoadBalancer deployment as per config."
fi

echo "🎉 All done! Kubernetes API and optional LoadBalancer kube-vip are ready!"
