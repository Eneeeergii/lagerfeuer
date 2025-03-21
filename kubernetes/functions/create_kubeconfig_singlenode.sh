#!/bin/bash
set -e

create_ha_kubeconfig_singlenode(){

    ORIGINAL_KUBECONFIG=$KUBECONFIG

    # Check if Kubeconfig exists
    if [ ! -f "$ORIGINAL_KUBECONFIG" ]; then
        echo "❌ Error: Original kubeconfig file not found at $ORIGINAL_KUBECONFIG"
        exit 1
    fi

    # Set the new KUBECONFIG in /etc/environment
    if grep -q "KUBECONFIG=" /etc/environment; then
        sed -i "s|KUBECONFIG=.*|KUBECONFIG=$ORIGINAL_KUBECONFIG|" /etc/environment
    else
        echo "KUBECONFIG=$ORIGINAL_KUBECONFIG" | sudo tee -a /etc/environment
    fi

    # Apply the new environment variable

    echo "✅ New KUBECONFIG set to $ORIGINAL_KUBECONFIG"
    echo "⚠️ Run 'source /etc/environment' or restart your session to apply the changes."

}