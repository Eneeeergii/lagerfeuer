#!/bin/bash
set -e

create_ha_kubeconfig(){

    ORIGINAL_KUBECONFIG=$1
    HA_KUBECONFIG=$2
    API_IP=$3
    NEW_URL="https://$API_IP:6443"

    echo $ORIGINAL_KUBECONFIG
    echo $HA_KUBECONFIG
    echo $API_IP
    echo $NEW_URL

    # Check if Kubeconfig exists
    if [ ! -f "$ORIGINAL_KUBECONFIG" ]; then
        echo "❌ Error: Original kubeconfig file not found at $ORIGINAL_KUBECONFIG"
        exit 1
    fi

    # Copy and rename config
    cp "$ORIGINAL_KUBECONFIG" "$HA_KUBECONFIG"

    # Set new Server URL
    sed -i "s|https://127.0.0.1:6443|$NEW_URL|g" "$HA_KUBECONFIG"

    # Verify changed URL
    if grep -q "$NEW_URL" "$HA_KUBECONFIG"; then
        echo "✅ Successfully updated server URL in $HA_KUBECONFIG "
    else
        echo "❌ Error: Failed to update server URL"
        exit 1
    fi

    # Set the new KUBECONFIG in /etc/environment
    if grep -q "KUBECONFIG=" /etc/environment; then
        sed -i "s|KUBECONFIG=.*|KUBECONFIG=$HA_KUBECONFIG|" /etc/environment
    else
        echo "KUBECONFIG=$HA_KUBECONFIG" | sudo tee -a /etc/environment
    fi

    # Apply the new environment variable

    echo "✅ New KUBECONFIG set to $HA_KUBECONFIG"
    echo "⚠️ Run 'source /etc/environment' or restart your session to apply the changes."

}