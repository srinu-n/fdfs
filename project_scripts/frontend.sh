#!/bin/bash

# this script is for the frontend (nginx). it serves the website and sends /api/... to the movie, booking and notification services

set -eE -o pipefail

# colours
R="\e[31m"   # red    - errors
G="\e[32m"   # green  - success / info
Y="\e[33m"   # yellow - skipping
N="\e[0m"    # reset to normal colour
project_folder=$(pwd)

trap 'echo -e "${R}Error on line $LINENO: Command \"$BASH_COMMAND\" exited with status $?${N}"' ERR

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

apt install -y nginx unzip curl

validate $? "apt install -y nginx unzip curl"

# ubuntu default site also listens on port 80 as default_server. if it stays, nginx will not start

if [ -f "/etc/nginx/sites-enabled/default" ]; then
    rm -f /etc/nginx/sites-enabled/default
    validate $? "removing the default site of nginx"
else
    echo -e "${Y} [SKIPPING $(date +"%F %T")] default site already removed${N}"
fi


# create the directory for website

mkdir -p /var/www/fdfs
validate $? "creating the directory"

# -f: fail if the download fails (otherwise curl saves the error page as the zip)
curl -f -o /tmp/frontend.zip https://fdfs-artifacts-30b67175.s3.amazonaws.com/frontend-v1.zip

validate $? "downloading the code"

unzip -o /tmp/frontend.zip -d /var/www/fdfs

validate $? "unzipping the code"


cp "$project_folder/nginx.conf" /etc/nginx/conf.d/fdfs.conf

validate $? "copying the nginx.conf"

# always test the config before restart. a broken config stops nginx from starting

nginx -t

validate $? "testing the nginx config"

systemctl enable nginx

validate $? "enabling nginx"

systemctl restart nginx

validate $? "restarting nginx"

# testing

curl -s localhost/nginx-health

validate $? "nginx health check"

curl -sf localhost/api/movies

validate $? "movies api through nginx"

# logs: tail -f /var/log/nginx/access.log /var/log/nginx/error.log