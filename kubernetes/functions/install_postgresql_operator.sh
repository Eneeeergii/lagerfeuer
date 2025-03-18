#!/bin/bash
set -e

#Enable this and the function calls at the bottom, to test this script isolated
CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
source "$CONFIG_FILE"
echo "✅ Loaded configuration from $CONFIG_FILE"

check_parameters(){

    if [ "$POSTGRESQL_OPERATOR_INSTALL" == "true" ]; then
        
        if [ -z "$POSTGRESQL_NAMESPACE" ]; then
            echo "❌ NAMESPACE is not set!"
            exit 1
        fi
        if [ -z "$POSTGRESQL_SPILO_VERSION" ]; then
            echo "❌ SPILO Version is not set!"
            exit 1
        fi
        if [ -z "$POSTGRESQL_OPERATOR_VERSION" ]; then
            echo "❌ OPERATOR Version is not set!"
            exit 1
        fi
    elif [ "$POSTGRESQL_OPERATOR_INSTALL" == "false" ]; then
        echo "⚙️ Skipping installation of PostgreSQL Operator"
    else
        echo "❌ Value of POSTGRESQL_OPERATOR_INSTALL: $POSTGRESQL_OPERATOR_INSTALL is not allowed!"
    fi

}

check_manifests(){

    if [ ! -f "$POSTGRESQL_NAMESPACE_MANIFEST" ]; then
        echo "❌ YAML file $POSTGRESQL_NAMESPACE_MANIFEST not found!"
        exit 1
    else
        echo "✅ YAML file $POSTGRESQL_NAMESPACE_MANIFEST loaded!"
    fi

    if [ ! -f "$POSTGRESQL_RBAC_MANIFEST" ]; then
        echo "❌ YAML file $POSTGRESQL_RBAC_MANIFEST not found!"
        exit 1
    else
        echo "✅ YAML file $POSTGRESQL_RBAC_MANIFEST loaded!"
    fi

    if [ ! -f "$POSTGRESQL_OPERATOR_CRD_MANIFEST" ]; then
        echo "❌ YAML file $POSTGRESQL_OPERATOR_CRD_MANIFEST not found!"
        exit 1
    else
        echo "✅ YAML file $POSTGRESQL_OPERATOR_CRD_MANIFEST loaded!"
    fi

    if [ ! -f "$POSTGRESQL_POSTGRESQLS_CRD_MANIFEST" ]; then
        echo "❌ YAML file $POSTGRESQL_POSTGRESQLS_CRD_MANIFEST not found!"
        exit 1
    else
        echo "✅ YAML file $POSTGRESQL_POSTGRESQLS_CRD_MANIFEST loaded!"
    fi

    if [ ! -f "$POSTGRESQL_POSTGRESQLTEAM_CRD_MANIFEST" ]; then
        echo "❌ YAML file $POSTGRESQL_POSTGRESQLTEAM_CRD_MANIFEST not found!"
        exit 1
    else
        echo "✅ YAML file $POSTGRESQL_POSTGRESQLTEAM_CRD_MANIFEST loaded!"
    fi

    if [ ! -f "$POSTGRESQL_OPERATORCONFIGURATION_MANIFEST" ]; then
        echo "❌ YAML file $POSTGRESQL_OPERATORCONFIGURATION_MANIFEST not found!"
        exit 1
    else
        echo "✅ YAML file $POSTGRESQL_OPERATORCONFIGURATION_MANIFEST loaded!"
    fi

    if [ ! -f "$POSTGRESQL_SERVICE_MANIFEST" ]; then
        echo "❌ YAML file $POSTGRESQL_SERVICE_MANIFEST not found!"
        exit 1
    else
        echo "✅ YAML file $POSTGRESQL_SERVICE_MANIFEST loaded!"
    fi

}

install_postgresql_operator(){

    check_parameters
    check_manifests

    #Check if Operator should be installed
    if [ "$POSTGRESQL_OPERATOR_INSTALL" == "true" ]; then

        export POSTGRESQL_NAMESPACE
        export POSTGRESQL_SPILO_VERSION
        export POSTGRESQL_OPERATOR_VERSION
        
        echo "⚙️ Creating Namespace"
        envsubst < $POSTGRESQL_NAMESPACE_MANIFEST | sed 's/["\\]//g' | kubectl apply -f - 
        echo "✅ Namespace created"

        echo "⚙️ Creating Cluster Role, Service Account & Cluster Role Binding"
        envsubst < $POSTGRESQL_RBAC_MANIFEST | sed 's/["\\]//g' | kubectl apply -f -
        echo "✅ Cluster Role, Service Account & Cluster Role Binding created"

        echo "⚙️ Creating Custom Ressource Definition"
        kubectl apply -f $POSTGRESQL_OPERATOR_CRD_MANIFEST
        echo "✅ Custom Ressource Definition created"

        echo "⚙️ Team Creating Custom Ressource Definition"
        kubectl apply -f $POSTGRESQL_POSTGRESQLS_CRD_MANIFEST
        echo "✅ Team Custom Ressource Definition created"

        echo "⚙️ Team Creating Custom Ressource Definition"
        kubectl apply -f $POSTGRESQL_POSTGRESQLTEAM_CRD_MANIFEST
        echo "✅ Team Custom Ressource Definition created"

        echo "⚙️ Deploying Operator"
        envsubst < $POSTGRESQL_OPERATORCONFIGURATION_MANIFEST | sed 's/["\\]//g' | kubectl apply -f -
        echo "✅ Operator deployed"

        echo "⚙️ Creating Operator Service"
        envsubst < $POSTGRESQL_SERVICE_MANIFEST | sed 's/["\\]//g' | kubectl apply -f -
        echo "✅ Service created"

        #unset $POSTGRESQL_NAMESPACE
        unset $POSTGRESQL_NAMESPACE
        unset $POSTGRESQL_SPILO_VERSION
        unset $POSTGRESQL_OPERATOR_VERSION

    elif [ "$POSTGRESQL_OPERATOR_INSTALL" == "false" ]; then

        echo "⚙️ Skipping installation of PostgreSQL Operator"

    fi

}

#Function Calls for isolation test
check_parameters
check_manifests
install_postgresql_operator