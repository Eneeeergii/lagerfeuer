#!/bin/bash

set -e  # Stop on error
set -o pipefail  # Catch pipeline errors

# Files
CONFIG_FILE="./config.env"
KUBE_VIP_YAML="./kube-vip-ds.yaml"  # YAML template with placeholders

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

# --- Deploy kube-vip ---
if [ ! -f "$KUBE_VIP_YAML" ]; then
    echo "❌ kube-vip YAML file '$KUBE_VIP_YAML' not found!"
    exit 1
fi

# Export variables for envsubst
export K3S_API_IP
export VIP_INTERFACE

echo "🚀 Deploying kube-vip with API IP $K3S_API_IP on interface $VIP_INTERFACE"

# Substitute variables and apply
envsubst < "$KUBE_VIP_YAML" | kubectl apply -f -

echo "✅ kube-vip deployed successfully!"
echo "🎉 Kubernetes API should now be reachable via: https://${K3S_API_IP}:6443"
