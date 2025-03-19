#!/bin/bash
set -e

#Enable this and the function calls at the bottom, to test this script isolated
CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
source "$CONFIG_FILE"
echo "✅ Loaded configuration from $CONFIG_FILE"

check_parameters_kubevip(){

    if [ -z "$VIP_LB_RANGE" ]; then
        echo "❌ NAMESPACE is not set!"
        exit 1
    fi

}

install_kubeVIP_cloud_provider_on_prem(){



    if [ "$DEPLOY_LB_KUBEVIP" == "true" ]; then

        export VIP_LB_RANGE
        echo $VIP_LB_RANGE

        envsubst < "$KUBE_VIP_LB_YAML" | kubectl apply -f -
        envsubst < "$KUBE_VIP_CLOUD_PROVIDER_CONFIGMAP_YAML" | kubectl apply -f -
        envsubst < "$KUBE_VIP_CLOUD_PROVIDER_YAML" | kubectl apply -f -
          
    elif [ "$DEPLOY_LB_KUBEVIP" == "false" ]; then

        echo "⚙️ Skipping installation of kubeVIP LoadBalancer!"

    else
        echo "❌ Value of POSTGRESQL_OPERATOR_INSTALL: $DEPLOY_LB_KUBEVIP is not allowed!"
    fi

}

install_kubeVIP_cloud_provider_on_prem