#!/bin/bash

# this script is for the movie svc. this will depend on the postgres and the redis for caching

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

apt install -y python3 python3-venv python3-pip unzip curl postgresql-client

validate $? "apt install -y python3 python3-venv python3-pip unzip curl postgresql-client"

if id fdfs; then
    echo " system user already there"
else
    echo " user are not there creating the user"
    useradd --system --no-create-home --shell /usr/sbin/nologin fdfs

fi


# create the directory for app

mkdir -p /opt/fdfs/movie-service


curl -o /tmp/movie-service.zip https://fdfs-artifacts-30b67175.s3.amazonaws.com/movie-service-v1.zip

cd /opt/fdfs/movie-service

unzip -o /tmp/movie-service.zip


# create the virtual environment

python3 -m venv /opt/fdfs/movie-service/venv

/opt/fdfs/movie-service/venv/bin/pip install -r /opt/fdfs/movie-service/requirements.txt

chown -R fdfs:fdfs /opt/fdfs/movie-service

mkdir -p /etc/fdfs

touch /etc/fdfs/movie-service.env

cp movies_svc_env.file /etc/fdfs/movie-service.env

chmod 600 /etc/fdfs/movie-service.env

PGPASSWORD=FdfsPass123 psql -h fdfs-postgre.srinun.in -U fdfs -d fdfs -f /opt/fdfs/movie-service/db/schema.sql

PGPASSWORD=FdfsPass123 psql -h fdfs-postgre.srinun.in -U fdfs -d fdfs -f /opt/fdfs/movie-service/db/seed.sql

cp movies_svc_systemd.file /etc/systemd/system/fdfs-movie-service.service

systemctl daemon-reload

systemctl enable --now fdfs-movie-service

systemctl status fdfs-movie-service --no-pager