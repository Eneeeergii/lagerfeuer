set -e

install_postgresql_operator(){

    #Check if Operator should be installed
    if [ "$HA_CLUSTER" == "true" ]; then
        if [ -z "$MASTERS" ]; then
            echo "❌ No MASTERS are set!"
            exit 1
        fi
    fi

}