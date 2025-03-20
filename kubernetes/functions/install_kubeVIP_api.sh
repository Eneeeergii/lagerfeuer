#!/bin/bash
set -e

#For isolated test do this first:
#CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
#source "$CONFIG_FILE"
#echo "✅ Loaded configuration from $CONFIG_FILE"

check_parameters(){

    if [ -z "$K3S_API_IP" ]; then
        echo "❌ K3S_API_IP is not set!"
        exit 1
    fi

    if [ -z "$VIP_INTERFACE" ]; then
        echo "❌ VIP_INTERFACE is not set!"
        exit 1
    fi

}

install_kubeVIP_HA_API(){

    check_parameters

    echo "🚀 Installing KubeVIP for API..."

    export K3S_API_IP
    export VIP_INTERFACE
    #echo $VIP_LB_RANGE

    envsubst < "$KUBE_VIP_API_YAML" | kubectl apply -f - > /dev/null 2>&1
    echo "✅ KubeVIP API DaemonSet applied!"

    unset $K3S_API_IP
    unset $VIP_INTERFACE

}

#install_kubeVIP_cloud_provider_on_prem