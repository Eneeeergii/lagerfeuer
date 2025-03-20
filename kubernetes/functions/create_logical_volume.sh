#!/bin/bash
set -e

#For isolated test do this first:
CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
source "$CONFIG_FILE"
echo "✅ Loaded configuration from $CONFIG_FILE"

check_logical_volume(){

    VG_NAME=$1
    LV_NAME=$2

    sudo lvdisplay "/dev/$VG_NAME/$LV_NAME" &> /dev/null

}

create_logical_volume(){

    LV_NAME=$1
    VG_NAME=$2
    LV_SIZE=$3
    BASE_MOUNT_POINT=$4
    MOUNT_POINT="$BASE_MOUNT_POINT$LV_NAME-storage"
    FSTAB_ENTRY="/dev/$VG_NAME/$LV_NAME $MOUNT_POINT ext4 defaults 0 0"

    if check_logical_volume; then
        echo "✅ Logical Volume '$LV_NAME' already exists in Volume Group '$VG_NAME'."
    else
        echo "⚠️ Logical Volume '$LV_NAME' does not exist. Creating it now..."
        lvcreate -L "$LV_SIZE" -n "$LV_NAME" "$VG_NAME"

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
        echo "❌ Error: Mount point '$MOUNT_POINT' already exists! Exiting..."
    fi

    # Mount the LV
    echo "🔄 Mounting Logical Volume..."
    sudo mount "/dev/$VG_NAME/$LV_NAME" "$MOUNT_POINT"

    # Verify mount success
    if mountpoint -q "$MOUNT_POINT"; then
        echo "✅ Successfully mounted at '$MOUNT_POINT'."
    else
        echo "❌ Error: Mounting failed. Exiting..."
        exit 1
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

}

echo $POSTGRESQL_LV_AND_PV_NAME 
echo $VOLUME_GROUP_NAME 
echo $POSTGRESQL_LV_AND_PV_SIZE 
echo $LOGICAL_VOLUME_MOUNT_POINT

create_logical_volume $POSTGRESQL_LV_AND_PV_NAME $VOLUME_GROUP_NAME $POSTGRESQL_LV_AND_PV_SIZE $LOGICAL_VOLUME_MOUNT_POINT