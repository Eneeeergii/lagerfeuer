#!/bin/bash
set -e

install_firstnode_local(){

    if [ -z "$K3S_VERSION" ]; then
        echo "❌ K3S_VERSION is not set!"
        exit 1
    fi

    if [ -z "$K3S_TOKEN" ]; then
        echo "❌ K3S_TOKEN is not set!"
        exit 1
    fi

    if [ -z "$INSTALL_K3S_FIRSTNODE" ]; then
        echo "❌ K3S_TOKEN is not set!"
        exit 1
    fi

    export INSTALL_K3S_EXEC="$INSTALL_K3S_FIRSTNODE"
    export INSTALL_K3S_VERSION="$K3S_VERSION"
    export K3S_TOKEN

    echo "🚀 Installing K3s version $K3S_VERSION with options: $INSTALL_K3S_EXEC"
    curl -sfL https://get.k3s.io | K3S_TOKEN=$K3S_TOKEN sh -s -
    echo "✅ K3s installed successfully!"

    unset $INSTALL_K3S_EXEC
    unset $INSTALL_K3S_VERSION
    unset $K3S_TOKEN


}