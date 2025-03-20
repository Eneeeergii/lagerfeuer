#!/bin/bash

set -e  # Stop on error
set -o pipefail  # Catch pipeline errors

# Include all functions
for file in ./functions/*.sh; do
    if [ -f "$file" ]; then
        source "$file"
    fi
done

# Environment File
CONFIG_FILE="./config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file '$CONFIG_FILE' not found!"
    exit 1
fi

source "$CONFIG_FILE"
echo "✅ Loaded configuration from $CONFIG_FILE"

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

install_additional_master_node $KUBECONFIG $KUBECONFIG_HA $K3S_API_IP

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
#check_volume_group $VOLUME_GROUP_NAME
#create_logical_volume $POSTGRESQL_LV_AND_PV_NAME $VOLUME_GROUP_NAME $POSTGRESQL_LV_AND_PV_SIZE $LOGICAL_VOLUME_MOUNT_POINT



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