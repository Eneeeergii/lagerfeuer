set -e  # Stop on error

check_file(){

    FILE=$1

    if [ ! -f "$FILE" ]; then
        echo "❌ File '$FILE' not found!"
        exit 1
    fi

}