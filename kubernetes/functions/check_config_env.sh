set -e  # Stop on error

check_config_env(){

    CONFIG_FILE=$1

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

    if [ -z "$K3S_TOKEN" ]; then
        echo "❌ K3S_TOKEN is not set!"
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

    if [ -z "$INSTALL_K3S_FIRSTNODE" ]; then
        echo "❌ INSTALL_K3S_FIRSTNODE is not set!"
        exit 1
    fi

    if [ "$HA_CLUSTER" == "true"]; then
        if [ -z "$MASTERS" ]; then
            echo "❌ No MASTERS are set!"
            exit 1
        fi
    fi

    if [ "$ADDITIONAL_WORKERS" == "true"]; then
        if [ -z "$WORKERS" ]; then
            echo "❌ No WORKERS are set!"
            exit 1
        fi
    fi

    if [ -z "$SSH_USER" ]; then
        echo "❌ SSH_USER is not set!"
        exit 1
    fi

    if [ -z "$SSH_KEY" ]; then
        echo "❌ SSH_KEY is not set!"
        exit 1
    fi

    if [ "$DEPLOY_LB_KUBEVIP" == "true"]; then
        if [ -z "$VIP_LB_RANGE" ]; then
            echo "❌ VIP_LB_RANGE is not set!"
            exit 1
        fi
    fi

}