#!/bin/bash
set -e

check_volume_group(){

    VG_NAME=$1

    if sudo vgdisplay "$VG_NAME" &> /dev/null; then
        echo "✅ Volume Group '$VG_NAME' exists."
    else
        echo "❌ Error: Volume Group '$VG_NAME' does not exist. Please create Volume Group and write it into config.env file!"
        exit 1
    fi

}