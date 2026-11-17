#!/bin/bash

set -eE -o pipefail

trap 'echo "Error on line $LINENO: Command \"$BASH_COMMAND\" exited with status $?"' ERR

# check the user is root or not

if [ $(id -u) -ne 0 ];then
    echo " please run with the sudo previlages"
    exit 1
fi

validate () {
        echo  " [SUCCESS  $(date +"%F %T")] $2 "
    
    else
        echo  "$ [ failed  $(date +"%F %T")] $2"
        exit 1
    fi
}

apt update -y

validate $? "apt update"

apt install -y redis-server

validate $? "apt install redis-server"



sed -i 's/^bind 127.0.0.1 -::1/bind 0.0.0.0/' /etc/redis/redis.conf

validate $? "open the redis from local to everyone"

sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf

validate $? "disable the protection mode for redis"

systemctl restart redis-server

validate $? "restart the server"

systemctl enable redis-server

validate $? "enable the server"
