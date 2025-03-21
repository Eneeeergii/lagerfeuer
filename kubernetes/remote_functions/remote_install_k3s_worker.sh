#!/bin/bash
set -e

CONFIG_FILE=/tmp/config.env
source "$CONFIG_FILE"
echo "✅ Loaded configuration from $CONFIG_FILE"

curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN K3S_URL=https://$K3S_API_IP:6443 sh -