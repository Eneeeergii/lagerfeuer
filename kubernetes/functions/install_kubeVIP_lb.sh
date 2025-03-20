#!/bin/bash
set -e

#For isolated test do this first:
#CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
#source "$CONFIG_FILE"
#echo "✅ Loaded configuration from $CONFIG_FILE"

check_parameters_kubevip(){

    if [ -z "$VIP_INTERFACE" ]; then
        echo "❌ VIP_INTERFACE is not set!"
        exit 1
    fi

    if [ -z "$VIP_LB_RANGE" ]; then
        echo "❌ VIP_LB_RANGE is not set!"
        exit 1
    fi

}

install_kubeVIP_SVC_LB(){

    check_parameters_kubevip

    if [ "$DEPLOY_LB_KUBEVIP" == "true" ]; then

        echo "🚀 Installing KubeVIP Loadbalancer Service..."

        export VIP_LB_RANGE
        export VIP_INTERFACE

        envsubst < "$KUBE_VIP_LB_YAML" | kubectl apply -f - > /dev/null 2>&1
        echo "✅ KubeVIP DaemonSet applied!"
        envsubst < "$KUBE_VIP_CLOUD_PROVIDER_CONFIGMAP_YAML" | kubectl apply -f - > /dev/null 2>&1
        echo "✅ KubeVIP Cloud Provider ConfigMap applied!"
        envsubst < "$KUBE_VIP_CLOUD_PROVIDER_YAML" | kubectl apply -f - > /dev/null 2>&1
        echo "✅ KubeVIP Cloud Provider on premise RBAC & Deployment applied!"

        unset $VIP_LB_RANGE
        unset $VIP_INTERFACE
          
    elif [ "$DEPLOY_LB_KUBEVIP" == "false" ]; then

        echo "⚙️ Skipping installation of kubeVIP LoadBalancer!"

    else

        echo "❌ Value of POSTGRESQL_OPERATOR_INSTALL: $DEPLOY_LB_KUBEVIP is not allowed!"

    fi

}

#install_kubeVIP_cloud_provider_on_prem