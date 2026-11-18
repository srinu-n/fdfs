#!/bin/bash


set -eE -o pipefail

trap 'echo "Error on line $LINENO: Command \"$BASH_COMMAND\" exited with status $?"' ERR


# we are going to deploy the postgreql using this.

R="\e[31m"
G="\e[32m"
N="\e[0m"
Y="\e[33m"
# check the user is root or no

if [ "$(id -u)" -ne 0 ]; then
    echo "please run the script with root privileges"
    exit 1
fi

validate () {
    if [ $1 -eq 0 ]; then

        echo -e "${G} [SUCCESS  $(date +"%F %T")] $2 ${N}"
    
    else
        echo -e "${R} [ failed  $(date +"%F %T")]    $2${N}"
        exit 1
    fi
}

apt update -y

validate $? "apt update"
# check the previous command is got suceded or not if not stop here itself

# write a simple function to follow dry principles

apt install -y rabbitmq-server

validate $? "apt install -y rabbitmq-server"


systemctl enable --now rabbitmq-server

validate $? "systemctl enable --now rabbitmq-server"

# check the package is installed or not

rabbitmqctl add_user fdfs FdfsPass123

validate $? "rabbitmqctl add_user fdfs FdfsPass123"

rabbitmqctl set_permissions -p / fdfs ".*" ".*" ".*"

validate $? "rabbitmqctl set_permissions -p / fdfs ".*" ".*" ".*""


# we need to update our app server pvt ips once we deployed 
rabbitmq-plugins enable rabbitmq_management

validate $? " rabbitmq-plugins enable rabbitmq_management"

