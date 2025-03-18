set -e

install_postgresql_operator(){

    CONFIG_FILE=$1

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Configuration file '$CONFIG_FILE' not found!"
        exit 1
    fi

    source "$CONFIG_FILE"
    echo "✅ Loaded configuration from $CONFIG_FILE"

    #Check if Operator should be installed
    if [ "$POSTGRESQL_OPERATOR_INSTALL" == "true" ]; then
        if [ -z "$POSTGRESQL_NAMESPACE" ]; then
            echo "❌ K3S_VERSION is not set!"
            exit 1
        fi
    else

    fi

}