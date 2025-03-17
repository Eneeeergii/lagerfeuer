#!/bin/bash
install_helm(){

# Function to check if a command exists
    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }

    echo "Checking if Helm is installed..."

    if command_exists helm; then
        echo "✅ Helm is already installed. Version:"
        helm version
    else
        echo "❌ Helm is not installed. Installing Helm..."

        # Update system
        sudo apt update

        # Install prerequisites
        sudo apt install curl apt-transport-https gnupg -y

        # Add Helm GPG key
        curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -

        # Add Helm repo
        echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

        # Update and install Helm
        sudo apt update
        sudo apt install helm -y

        # Verify installation
        if command_exists helm; then
            echo "✅ Helm installed successfully. Version:"
            helm version
        else
            echo "❌ Helm installation failed. Please check errors above."
            exit 1
        fi
    fi

}

install_helm
