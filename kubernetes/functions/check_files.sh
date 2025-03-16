set -e  # Stop on error

check_deployment(){

    KUBE_VIP_API_YAML=$1
    KUBE_VIP_LB_YAML=$2

    if [ ! -f "$KUBE_VIP_API_YAML" ]; then
        echo "❌ kube-vip API YAML file '$KUBE_VIP_API_YAML' not found!"
        exit 1
    fi

    if [ ! -f "$KUBE_VIP_API_YAML" ]; then
        echo "❌ kube-vip API YAML file '$KUBE_VIP_API_YAML' not found!"
        exit 1
    fi

}

check_kubeconfig(){

    KUBECONFIG_FILE=$1

    if [ ! -f "$KUBE_VIP_API_YAML" ]; then
        echo "❌ kube-vip API YAML file '$KUBE_VIP_API_YAML' not found!"
        exit 1
    fi

}