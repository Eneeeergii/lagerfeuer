#!/bin/bash
set -e

#For isolated test do this first:
#CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
#source "$CONFIG_FILE"
#echo "✅ Loaded configuration from $CONFIG_FILE"

install_additional_worker_node(){

    if [ "$ADDITIONAL_WORKERS" == "true" ]; then
        
        if [ -z "$WORKERS" ]; then
            echo "❌ WORKERS is not set!"
            exit 1
        fi

        IFS=',' read -r -a WORKER_NODES <<< "$WORKERS"
    
        for worker in "${WORKER_NODES[@]}"; do
            echo "🚀 Copying Files to $worker"
            scp -i "$SSH_KEY" ./remote_functions/remote_install_k3s_worker.sh "$SSH_USER@$worker:/tmp/remote_install_k3s_worker.sh"
            scp -i "$SSH_KEY" ./config.env "$SSH_USER@$worker:/tmp/config.env"

            echo "🚀 Installing K3s version $K3S_VERSION on $worker and adding it to the K3s Cluster"
            ssh -i "$SSH_KEY" "$SSH_USER@$worker" "bash /tmp/remote_install_k3s_worker.sh"
            echo "✅ K3s installed, KUBECONFIG chenged and $worker is added to K3s Cluster!"
            
            echo "🚀 Deleting files on $worker"
            ssh -i "$SSH_KEY" "$SSH_USER@$worker" "rm -f /tmp/remote_install_k3s_worker.sh"
            ssh -i "$SSH_KEY" "$SSH_USER@$worker" "rm -f /tmp/config.env"
            echo "✅ All files deleted on $worker"
        done
    
    elif [ "$ADDITIONAL_WORKERS" == "false" ]; then
        echo "✅ No Worker will be added to the Cluster!"
    else
        echo "❌ Current value of ADDITIONAL_WORKERS is not allowed: $ADDITIONAL_WORKERS"
        exit 1
    fi

}

#install_additional_master_node $KUBECONFIG $KUBECONFIG_HA $K3S_API_IP