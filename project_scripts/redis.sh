#!/bin/bash

set -eE -o pipefail

# colours
R="\e[31m"   # red    - errors
G="\e[32m"   # green  - success
N="\e[0m"    # reset to normal colour

trap 'echo -e "${R}Error on line $LINENO: Command \"$BASH_COMMAND\" exited with status $?${N}"' ERR

# check the user is root or not

if [ $(id -u) -ne 0 ];then
    echo -e "${R} [ERROR    $(date +"%F %T")] please run the script with root privileges (sudo)${N}"
    exit 1
fi

validate () {
    if [ $1 -eq 0 ];then
        echo -e "${G} [SUCCESS  $(date +"%F %T")] $2${N}"
    else
        echo -e "${R} [FAILED   $(date +"%F %T")] $2${N}"
        exit 1
    fi
}

apt update -y

validate $? "apt update"

apt install -y redis-server

validate $? "install redis-server"



sed -i 's/^bind 127.0.0.1 -::1/bind 0.0.0.0/' /etc/redis/redis.conf

validate $? "redis now listens on all interfaces (bind 0.0.0.0)"

sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf

validate $? "protected mode disabled, so other servers can connect"

systemctl restart redis-server

validate $? "restart redis-server"

systemctl enable redis-server

validate $? "enable redis-server to start on boot"