#!/bin/bash

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

apt install -y postgresql-common ca-certificates

validate $? "install -y postgresql-common ca-certificates"



/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

validate $? "/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh"


# check the package is installed or not

apt install -y postgresql-18

validate $? "apt install -y postgresql-18"

sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/18/main/postgresql.conf

validate $? "sed command update to listen anywhere"


# we need to update our app server pvt ips once we deployed 
echo "host    fdfs    fdfs    0.0.0.0/0    scram-sha-256" >> /etc/postgresql/18/main/pg_hba.conf

validate $? " /etc/postgresql/18/main/pg_hba.conf"


# restart and enable the service

systemctl restart postgresql

validate $? "systemctl restart postgresql"


systemctl enable postgresql

validate $? "systemctl enable postgresql"


# create the fdfs user only if it does not exist
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='fdfs'" | grep -q 1

if [ $? -eq 0 ]; then
    echo -e "${Y} [SKIPPING $(date +"%F %T")] fdfs user already exists ${N}"
else
    sudo -u postgres psql -c "CREATE USER fdfs WITH PASSWORD 'FdfsPass123';"
    validate $? "creating the fdfs user for app"
fi

# create the fdfs database only if it does not exist
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='fdfs'" | grep -q 1

if [ $? -eq 0 ]; then
    echo -e "${Y} [SKIPPING $(date +"%F %T")] fdfs database already exists ${N}"
else
    sudo -u postgres psql -c "CREATE DATABASE fdfs OWNER fdfs;"
    validate $? "creating the fdfs db for app"
fi

