#!/bin/bash
set -e

#Enable this and the function calls at the bottom, to test this script isolated
#CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
#source "$CONFIG_FILE"
#echo "✅ Loaded configuration from $CONFIG_FILE"

check_helm_command_exists(){

    command -v "$1" >/dev/null 2>&1

}

check_parameters(){

    if [ "$POSTGRESQL_OPERATOR_INSTALL" == "true" ]; then
        
        if [ -z "$POSTGRESQL_NAMESPACE" ]; then
            echo "❌ NAMESPACE is not set!"
            exit 1
        fi
    else
        echo "❌ Value of POSTGRESQL_OPERATOR_INSTALL: $POSTGRESQL_OPERATOR_INSTALL is not allowed!"
    fi

}

install_helm(){

    echo "\n🔍 Checking Helm installation..."

    if ! check_helm_command_exists helm; then
        echo "🚨 Helm is not installed. Installing..."
        curl -s https://baltocdn.com/helm/signing.asc | apt-key add -
        apt-get install -y apt-transport-https
        echo "deb https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list > /dev/null
        apt-get update
        apt-get install -y helm
        echo "✅ Helm installed successfully!"
    else
        echo "✅ Helm is already installed. Checking for Updates..."
        apt-get update
        apt-get install --only-upgrade helm && echo "✅ Helm upgraded successfully!" || echo "⚠️ No Updates for Helm available."
    fi

    echo "\n🔍 Checking Helm-Repositories..."

    if helm repo list | grep -q "https"; then
        echo "🔄 Found Helm-Repositories. Running Update..."
        helm repo update && echo "✅ Helm-Repositories successfully updated!" || echo "❌ Error during repository updates."
    else
        echo "ℹ️ No Helm-Repositories found. There is nothing to update."
    fi

    echo "\n🎉 Helm installation finished!"

}

install_postgresql_operator(){

    operator_install=$1
    namespace=$2
    kubeconfig=$3
    
    if [ "$POSTGRESQL_OPERATOR_INSTALL" == "true" ]; then

        check_parameters
        install_helm
       
        echo "\n🔄 Adding Zalando PostgreSQL Operator Helm repository..."
        helm repo add zalando https://opensource.zalando.com/postgres-operator/charts/
        helm repo update

        echo "\n🚀 Installing Zalando PostgreSQL Operator..."
        kubectl create namespace $namespace || echo "⚠️ Namespace already exists."
        helm upgrade --install postgres-operator zalando/postgres-operator -n $namespace --kubeconfig=$kubeconfig

        echo "\n🎉 Zalando PostgreSQL Operator has been successfully installed!"
        
    elif [ "$POSTGRESQL_OPERATOR_INSTALL" == "false" ]; then

        echo "⚙️ Skipping installation of PostgreSQL Operator"

    fi

}

#Function Calls for isolation test
#export POSTGRESQL_OPERATOR_INSTALL
#export POSTGRESQL_NAMESPACE
#export KUBECONFIG
#install_postgresql_operator $POSTGRESQL_OPERATOR_INSTALL $POSTGRESQL_NAMESPACE $KUBECONFIG 