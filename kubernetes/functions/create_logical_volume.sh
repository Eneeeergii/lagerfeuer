#!/bin/bash
set -e

#For isolated test do this first:
CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
source "$CONFIG_FILE"
echo "✅ Loaded configuration from $CONFIG_FILE"

check_logical_volume(){

    sudo lvdisplay "/dev/$VG_NAME/$LV_NAME" &> /dev/null

}

create_logical_volume(){

    VG_NAME=$VOLUME_GROUP_NAME
    BASE_MOUNT_POINT=$LOGICAL_VOLUME_MOUNT_POINT

    IFS=',' read -r -a LVS <<< "$LOGICAL_VOLUMES"

    for lv in "${LVS[@]}"; do

        NAME=$lv
        LV_NAME="lv_k3s_$NAME"
        MOUNT_POINT="$BASE_MOUNT_POINT$NAME"
        FSTAB_ENTRY="/dev/$VG_NAME/$NAME $MOUNT_POINT ext4 defaults 0 0"
        i=1

        IFS=',' read -r -a SIZES <<< "$LOGICAL_VOLUMES_SIZE"

        size="${SIZES[$i]}"

        LV_SIZE=$size

        # Create LV if not already exist
        if check_logical_volume; then
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

        ((i++))
done

}

create_logical_volume