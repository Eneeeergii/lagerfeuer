#!/bin/bash
set -e

#Enable this and the function calls at the bottom, to test this script isolated
#CONFIG_FILE=/home/k3s-install/lagerfeuer/kubernetes/config.env
#source "$CONFIG_FILE"
#echo "✅ Loaded configuration from $CONFIG_FILE"

check_manifests(){

    if [ ! -f "$POSTGRESQL_MANIFEST_YAML" ]; then
        echo "❌ YAML file $POSTGRESQL_MANIFEST_YAML not found!"
        exit 1
    else
        echo "✅ YAML file $POSTGRESQL_MANIFEST_YAML loaded!"
    fi

}

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

install_postgresql_operator(){

    check_parameters
    check_manifests

    #Check if Operator should be installed
    if [ "$POSTGRESQL_OPERATOR_INSTALL" == "true" ]; then

        export POSTGRESQL_NAMESPACE
        export POSTGRESQL_SPILO_VERSION
        export POSTGRESQL_OPERATOR_VERSION
        
        echo "⚙️ Installing PostgreSQL Operator by Zalando"
        envsubst < $POSTGRESQL_MANIFEST_YAML | sed 's/["\\]//g' | kubectl apply -f - 
        echo "✅ "

        #unset $POSTGRESQL_NAMESPACE
        unset $POSTGRESQL_NAMESPACE
        unset $POSTGRESQL_SPILO_VERSION
        unset $POSTGRESQL_OPERATOR_VERSION

    elif [ "$POSTGRESQL_OPERATOR_INSTALL" == "false" ]; then

        echo "⚙️ Skipping installation of PostgreSQL Operator"

    fi

}

#Function Calls for isolation test
#check_parameters
#check_manifests
#install_postgresql_operator
