set -e

remove_sudoers_permission_remote(){

    HOST=$1
    USER=$2
    userdel k3s-install $USER

}

remove_sudoers_permission_local(){

    HOST=$1
    USER=$2
    userdel k3s-install $USER

}