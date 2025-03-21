curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s - server --server https://$K3S_API_IP:6443 --write-kubeconfig-mode 644
if [ ! -f "$ORIGINAL_KUBECONFIG" ]; then
    echo "❌ Error: Original kubeconfig file not found at $ORIGINAL_KUBECONFIG"
    exit 1
fi

sudo cp "$ORIGINAL_KUBECONFIG" "$HA_KUBECONFIG"
sudo sed -i "s|https://127.0.0.1:6443|$NEW_URL|g" "$HA_KUBECONFIG"

if grep -q "$NEW_URL" "$HA_KUBECONFIG"; then
    echo "✅ Successfully updated server URL in $HA_KUBECONFIG on $master"
else
    echo "❌ Error: Failed to update server URL on $master"
    exit 1
fi

if grep -q "KUBECONFIG=" /etc/environment; then
    sudo sed -i "s|KUBECONFIG=.*|KUBECONFIG=$HA_KUBECONFIG|" /etc/environment
else
    echo "KUBECONFIG=$HA_KUBECONFIG" | sudo tee -a /etc/environment
fi

echo "✅ New KUBECONFIG set to $HA_KUBECONFIG on $master"

VG_NAME=$VOLUME_GROUP_NAME
BASE_MOUNT_POINT=$LOGICAL_VOLUME_MOUNT_POINT

IFS=',' read -r -a LVS <<< "$LOGICAL_VOLUMES"
IFS=',' read -r -a SIZES <<< "$LOGICAL_VOLUMES_SIZE"
i=0

for lv in "${LVS[@]}"; do

    NAME=$lv
    LV_NAME="lv_k3s_$NAME"
    MOUNT_POINT="$BASE_MOUNT_POINT$NAME"
    FSTAB_ENTRY="/dev/$VG_NAME/$NAME $MOUNT_POINT ext4 defaults 0 0"
    size="${SIZES[$i]}"
    LV_SIZE=$size

    # Create LV if not already exist
    if sudo lvdisplay "/dev/$VG_NAME/$LV_NAME" &> /dev/null; then
        echo "✅ Logical Volume '$LV_NAME' already exists in Volume Group '$VG_NAME'."
    else
        echo "⚠️ Logical Volume '$LV_NAME' does not exist. Creating it now..."
        lvcreate -y -L "$LV_SIZE" -n "$LV_NAME" "$VG_NAME"

        if check_logical_volume; then
            echo "✅ Logical Volume '$LV_NAME' created successfully."
        else
            echo "❌ Error: Failed to create Logical Volume '$LV_NAME'. Exiting..."
            exit 1
        fi
    fi

    # Check if LV is formatted
    if ! sudo blkid "/dev/$VG_NAME/$LV_NAME" &> /dev/null; then
        echo "⚠️ Logical Volume '$LV_NAME' is not formatted. Formatting now..."
        mkfs.ext4 "/dev/$VG_NAME/$LV_NAME"
        echo "✅ Formatting complete."
    else
        echo "✅ Logical Volume '$LV_NAME' is already formatted."
    fi

    # Ensure the mount point exists
    if [ ! -d "$MOUNT_POINT" ]; then
        echo "⚠️ Mount point '$MOUNT_POINT' does not exist. Creating it now..."
        sudo mkdir -p "$MOUNT_POINT"
    else
        echo "✅ Mount point '$MOUNT_POINT' already exists!"
    fi


    # Verify mount success
    if mountpoint -q "$MOUNT_POINT"; then
        echo "✅ Successfully mounted at '$MOUNT_POINT'."
    else
        # Mount the LV
        echo "🔄 Mounting Logical Volume..."
        sudo mount "/dev/$VG_NAME/$LV_NAME" "$MOUNT_POINT"

        if mountpoint -q "$MOUNT_POINT"; then
            echo "✅ Successfully mounted at '$MOUNT_POINT'."
        else
            echo "❌ Error: Logical Volume could not be mounted"
            exit !
        fi
    fi

    # Add entry to fstab if not already present
    if ! grep -qs "/dev/$VG_NAME/$LV_NAME" /etc/fstab; then
        echo "🔄 Adding mount entry to /etc/fstab..."
        echo "$FSTAB_ENTRY" | tee -a /etc/fstab
        echo "✅ fstab entry added."
    else
        echo "✅ fstab entry already exists."
    fi

    # Reload systemd daemon
    echo "🔄 Reloading systemd daemon..."
    sudo systemctl daemon-reload
    echo "✅ systemd daemon reloaded."

    echo "🎉 Setup complete! Logical Volume '$LV_NAME' is mounted at '$MOUNT_POINT'."

    ((++i))
done