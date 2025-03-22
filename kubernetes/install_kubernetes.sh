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


if [ "$HA_CLUSTER" == "true" ]; then

    ### --- Install K3s on First Node ---
    install_firstnode_local

    # --- Deploy kube-vip for Kubernetes API VIP ---

    #Check if Deployment exists

    check_file $KUBE_VIP_API_YAML

    #Install KubeVIP for API

    install_kubeVIP_HA_API

    # --- Deploy KubeVIP & KubeVIP Cloud Provider for Load Balancing ---

    #Check if Deployments exist
    check_file $KUBE_VIP_LB_YAML
    check_file $KUBE_VIP_CLOUD_PROVIDER_YAML
    check_file $KUBE_VIP_CLOUD_PROVIDER_CONFIGMAP_YAML

    # Install KubeVIP for Service LB

    install_kubeVIP_SVC_LB

    # --- Create KUBECONFIG with API IP ---

    create_ha_kubeconfig

    ### --- Adding Master Nodes ---

    install_additional_master_node

    ### --- Adding WORKER Nodes ---

    install_additional_worker_node

    # --- Installation of PostgreSQL Operator --- 
    #install_postgresql_operator $POSTGRESQL_OPERATOR_INSTALL $POSTGRESQL_NAMESPACE $KUBECONFIG
elif [ "$HA_CLUSTER" == "false" ]; then

    echo "✅ K3s Single is ready to go"

    ### --- Install K3s on First Node ---
    install_firstnode_local
    create_ha_kubeconfig_singlenode

else
    echo "❌ Value of HA_CLUSTER is not valid!"
    exit 1
fi
