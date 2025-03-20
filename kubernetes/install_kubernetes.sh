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

# Include all functions
for file in ./functions/*.sh; do
    if [ -f "$file" ]; then
        source "$file"
    fi
done

#Check Output of Variables
#echo $KUBE_VIP_API_YAML
#echo $KUBE_VIP_LB_YAML
#echo $INSTALL_K3S_EXEC="$INSTALL_K3S_FIRSTNODE"
#echo $INSTALL_K3S_VERSION="$K3S_VERSION"
#echo $K3S_TOKEN
#echo $K3S_API_IP
#echo $VIP_INTERFACE
#echo $VIP_LB_RANGE
#echo $DEPLOY_LB_KUBEVIP
#echo $KUBECONFIG
#echo $SH_USER
#echo $SSH_KEY
#echo $POSTGRESQL_OPERATOR_INSTALL
#echo $POSTGRESQL_NAMESPACE

# --- Install K3s on First Node ---

install_firstnode_local

# --- Deploy kube-vip for Kubernetes API VIP ---

# Check if Deployment exists
check_file $KUBE_VIP_API_YAML

# Install KubeVIP for API
install_kubeVIP_HA_API
sleep 40

# --- Deploy KubeVIP & KubeVIP Cloud Provider for Load Balancing ---

# Check if Deployments exist
check_file $KUBE_VIP_LB_YAML
check_file $KUBE_VIP_CLOUD_PROVIDER_YAML
check_file $KUBE_VIP_CLOUD_PROVIDER_CONFIGMAP_YAML

# Install KubeVIP for Service LB
install_kubeVIP_SVC_LB

# --- Create KUBECONFIG with API IP ---

create_ha_kubeconfig $KUBECONFIG $KUBECONFIG_HA $K3S_API_IP

# --- Add further Master Nodes ---

install_additional_master_node

#if [ "$HA_CLUSTER" == "true" ]; then
#    IFS=',' read -r -a MASTER_NODES <<< "$MASTERS"
#    
#    for master in "${MASTER_NODES[@]}"; do
#        echo "🚀 Installing K3s version $K3S_VERSION on $master and adding it to the K3s Cluster"
#        ssh -i "$SSH_KEY" "$SSH_USER@$master" << EOF
#curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s - server --server https://$K3S_API_IP:6443 --write-kubeconfig-mode 644
#EOF
#        echo "✅ K3s installed and $master is added to K3s Cluster!"
#    done
#elif [ "$HA_CLUSTER" == "false" ]; then
#    echo "✅ K3S installed as a Single Node"
#else
#    echo "Please Check HA_CLUSTER Parameter, actual value is: $HA_CLUSTER"
#    exit 1
#fi

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

# --- Deploy Wordpress ---

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