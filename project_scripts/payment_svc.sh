#!/bin/bash


set -eE -o pipefail

trap 'echo "Error on line $LINENO: Command \"$BASH_COMMAND\" exited with status $?"' ERR


# we are going to deploy the postgreql using this.

R="\e[31m"
G="\e[32m"
N="\e[0m"
Y="\e[33m"

CURRENT_PATH=$(pwd)
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

apt install -y default-jdk-headless maven unzip curl

validate $? "apt install -y default-jdk-headless maven unzip curl"


if id fdfs; then
    echo " system user already there"
else
    echo " user are not there creating the user"
    useradd --system --no-create-home --shell /usr/sbin/nologin fdfs

fi


mkdir -p /tmp/payment-service

validate $? "creating the directory"

curl -o /tmp/payment-service.zip https://fdfs-artifacts-30b67175.s3.amazonaws.com/payment-service-v1.zip

validate $? "downloading the code"

unzip -o /tmp/payment-service.zip -d /tmp/payment-service

validate $? "unzipping the code"


cd /tmp/payment-service
validate $? "moving to the tmp folder"

mvn clean package -DskipTests

validate $? "running the clean package"

if  [ -f "target/payment-service.jar" ]; then
    echo " the jar file found"
else
    echo "maven build got failed need to validate"
    exit 1
fi

mkdir -p /opt/fdfs/payment-service

validate $? "creating the directory for env file"

cp /tmp/payment-service/target/payment-service.jar /opt/fdfs/payment-service/app.jar

validate $? "copying the jat file to the servvice path"

chown -R fdfs:fdfs /opt/fdfs/payment-service

validate $? " changing the file permissions"

mkdir -p /etc/fdfs
validate $? "creating the directory"

cp "${CURRENT_PATH}/payments_svc.file" /etc/fdfs/payment-service.env
validate $? "copying the service file"

chmod 600 /etc/fdfs/payment-service.env

validate $? "changing the permisiosns"



# copy the service file

cp "$CURRENT_PATH/payments_svc_systemd.file" /etc/systemd/system/fdfs-payment-service.service
validate $? "copy the service file"

systemctl daemon-reload

validate $? " reloading the svc"

systemctl enable --now fdfs-payment-service

validate $? "enabling the payemnts svc"

