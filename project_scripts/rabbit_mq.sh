#!/bin/bash


set -eE -o pipefail

# colours
R="\e[31m"   # red    - errors
G="\e[32m"   # green  - success / info
Y="\e[33m"   # yellow - skipping
N="\e[0m"    # reset to normal colour

trap 'echo -e "${R}Error on line $LINENO: Command \"$BASH_COMMAND\" exited with status $?${N}"' ERR


# we are going to deploy the postgreql using this.

# check the user is root or no

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${R} [ERROR    $(date +"%F %T")] please run the script with root privileges (sudo)${N}"
    exit 1
fi

validate () {
    if [ $1 -eq 0 ]; then
        echo -e "${G} [SUCCESS  $(date +"%F %T")] $2${N}"
    else
        echo -e "${R} [FAILED   $(date +"%F %T")] $2${N}"
        exit 1
    fi
}

apt update -y

validate $? "apt update"
# check the previous command is got suceded or not if not stop here itself

# write a simple function to follow dry principles

apt install -y rabbitmq-server

validate $? "install rabbitmq-server"


systemctl enable --now rabbitmq-server

validate $? "start rabbitmq-server and enable it on boot"

# check the user is there or not



if sudo rabbitmqctl authenticate_user fdfs 'FdfsPass123'; then 
    echo -e "${Y} [SKIPPING $(date +"%F %T")] rabbitmq user fdfs already exists, no need to create it or set permissions${N}"
else
    echo -e "${G} [INFO     $(date +"%F %T")] rabbitmq user fdfs not found, creating it${N}"
    rabbitmqctl add_user fdfs FdfsPass123
    rabbitmqctl set_permissions -p / fdfs ".*" ".*" ".*"
fi



# we need to update our app server pvt ips once we deployed 
rabbitmq-plugins enable rabbitmq_management

validate $? "enable the management plugin (web UI on port 15672)"