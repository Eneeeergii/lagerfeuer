#!/bin/bash
set -e

#For isolated test do this first:
#CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
#source "$CONFIG_FILE"
#echo "✅ Loaded configuration from $CONFIG_FILE"

install_additional_master_node(){

    ORIGINAL_KUBECONFIG=$KUBECONFIG
    HA_KUBECONFIG=$KUBECONFIG_HA
    API_IP=$K3S_API_IP
    NEW_URL="https://$API_IP:6443"

    CURRENT_HOSTNAME=$(hostname)

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

        if [[ "$CURRENT_HOSTNAME" != "$master" ]]; then

            echo "🚀 Installing K3s version $K3S_VERSION on $master and adding it to the K3s Cluster"
            ssh -i "$SSH_KEY" "$SSH_USER@$master" 'bash -s ' < ./functions/remote_functions/install_k3s_remote.sh
            echo "✅ K3s installed, KUBECONFIG chenged and $master is added to K3s Cluster!"

        fi
    done
    
    elif [ "$HA_CLUSTER" == "false" ]; then
        echo "✅ K3S installed as a Single Node"
    else
        echo "❌ Current value of HA_CLUSTER is not allowed: $HA_CLUSTER"
        exit 1
    fi

    unset $K3S_TOKEN

}

#install_additional_master_node $KUBECONFIG $KUBECONFIG_HA $K3S_API_IP