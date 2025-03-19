#!/bin/bash

set -e  # Stop on error
set -o pipefail  # Catch pipeline errors

# Environment File
CONFIG_FILE="./config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file '$CONFIG_FILE' not found!"
    exit 1
fi

source "$CONFIG_FILE"
echo "✅ Loaded configuration from $CONFIG_FILE"

# Functions
source ./functions/check_config_env.sh
source ./functions/check_files.sh
source ./functions/install_postgresql_operator.sh
source ./functions/install_kubeVIP_lb.sh

# Variables
export KUBE_VIP_API_YAML
export KUBE_VIP_LB_YAML
export INSTALL_K3S_EXEC="$INSTALL_K3S_FIRSTNODE"
export INSTALL_K3S_VERSION="$K3S_VERSION"
export K3S_TOKEN
export K3S_API_IP
export VIP_INTERFACE
export VIP_LB_RANGE
export DEPLOY_LB_KUBEVIP
export KUBECONFIG
export SSH_USER
export SSH_KEY
export POSTGRESQL_OPERATOR_INSTALL
export POSTGRESQL_NAMESPACE

#Check Output of Variables
#echo $KUBE_VIP_API_YAML
#echo $KUBE_VIP_LB_YAML
#echo $INSTALL_K3S_EXEC="$INSTALL_K3S_FIRSTNODE"
#echo $INSTALL_K3S_VERSION="$K3S_VERSION"
#echo $K3S_TOKEN
#echo $K3S_API_IP
#echo $VIP_INTERFACE
echo $VIP_LB_RANGE
#echo $DEPLOY_LB_KUBEVIP
#echo $KUBECONFIG
#echo $SH_USER
#echo $SSH_KEY
#echo $POSTGRESQL_OPERATOR_INSTALL
#echo $POSTGRESQL_NAMESPACE

# Check Deployments
check_deployment $KUBE_VIP_API_YAML $KUBE_VIP_LB_YAML

# --- Install K3s on First Node ---

echo "🚀 Installing K3s version $K3S_VERSION with options: $INSTALL_K3S_EXEC"
curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s -
echo "✅ K3s installed successfully!"

# --- Deploy kube-vip for Kubernetes API VIP ---

echo "🚀 Deploying kube-vip for Kubernetes API at $K3S_API_IP on interface $VIP_INTERFACE"
envsubst < "$KUBE_VIP_API_YAML" | kubectl apply -f -
echo "✅ kube-vip for Kubernetes API deployed!"

# --- Deploy KubeVIP & KubeVIP Cloud Provider for Load Balancing ---

install_kubeVIP_cloud_provider_on_prem $VIP_LB_RANGE

# --- Add API IP in Kubeconfig ---

check_kubeconfig $KUBECONFIG

echo "🔧 Replacing 127.0.0.1 with ${K3S_API_IP} in $KUBECONFIG"
sed -i "s/127.0.0.1/${K3S_API_IP}/g" "$KUBECONFIG"
echo "✅ K3s kubeconfig updated to use ${K3S_API_IP}"

# --- Add further Master Nodes ---

if [ "$HA_CLUSTER" == "true" ]; then
    IFS=',' read -r -a MASTER_NODES <<< "$MASTERS"
    
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

# --- Installation of PostgreSQL Operator --- 
install_postgresql_operator $POSTGRESQL_OPERATOR_INSTALL $POSTGRESQL_NAMESPACE $KUBECONFIG

# --- Unset all Variables --- 
unset $POSTGRESQL_OPERATOR_INSTALL
unset $POSTGRESQL_NAMESPACE
unset $SSH_USER
unset $SSH_KEY
unset $IP_LB_RANGE
unset $DEPLOY_LB_KUBEVIP
unset $VIP_INTERFACE
unset $KUBE_VIP_LB_YAML
unset $K3S_API_IP
unset $KUBE_VIP_API_YAML
unset $INSTALL_K3S_EXEC
unset $INSTALL_K3S_VERSION
unset $K3S_TOKEN