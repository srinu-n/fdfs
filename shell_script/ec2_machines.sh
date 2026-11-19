#!/bin/bash

set -eE
#!/bin/bash
set -eE -o pipefail

trap 'echo "Error on line $LINENO: Command \"$BASH_COMMAND\" exited with status $?"' ERR

# this script to create an ec2 machine

AMI_ID=ami-0547ecbf0e9b4aeb5
REGION=us-east-1
PREFIX=fdfs
ROOT_DOMAIN="srinun.in"
KEY_PAIR="fdfs"
SUBNET_ID=subnet-01898aa9d9e74970f
VPC_ID=vpc-0bf3a8f73da50ede9
HOSTED_ZONE_ID="Z073049822ZRUT7YAEASI"

# colours
R="\e[31m"   # red - errors
G="\e[32m"   # green - info / success
Y="\e[33m"   # yellow - warning / skipping
N="\e[0m"    # reset to normal colour

# if the user not provided the delete and create instead he provided something else
# we can break it here itself and guide him how to use the script
if [[ $1 == "create" || $1 == "delete" ]]; then
    echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] The user knows how to use the script. Continuing.${N}"
else
    echo -e "${R}[ERROR $(date +"%Y-%m-%d %H:%M:%S")] Invalid operation. Please provide create or delete.${N}"
    echo -e "${R}[ERROR $(date +"%Y-%m-%d %H:%M:%S")] Script usage: $0 <create | delete> machine_name${N}"
    exit 1
fi

# check the user passed the create or delete statement but not the machine name we need to validate it also
if [ $# -gt 1 ]; then
    echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Machine name argument provided. Continuing.${N}"
else
    echo -e "${R}[ERROR $(date +"%Y-%m-%d %H:%M:%S")] Machine name is missing.${N}"
    echo -e "${R}[ERROR $(date +"%Y-%m-%d %H:%M:%S")] Usage: $0 <create | delete> machine_name${N}"
    exit 1
fi



common_sg=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-0bf3a8f73da50ede9" "Name=group-name,Values=fdfs-common-sg" --region us-east-1 --query "SecurityGroups[*].GroupId" --output text)

if [ -z "${common_sg}" ];then
    echo " the common sg is not there lets create one"
     aws ec2 create-security-group \
    --group-name fdfs-common-sg \
    --description "Security group to enable ssh" \
    --vpc-id ${VPC_ID}
else
    echo " the common sg is already found no need to create"

fi

# need to get the id so again i need to call this

common_sg=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-0bf3a8f73da50ede9" "Name=group-name,Values=fdfs-common-sg" --region us-east-1 --query "SecurityGroups[*].GroupId" --output text)

if [ $1 == "create" ]; then
    echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Starting EC2 instance creation.${N}"
    shift

    for machine in "$@"; do
        echo -e "${Y}[WARNING $(date +"%Y-%m-%d %H:%M:%S")] Processing machine: $machine${N}"

        # check the sg is exist or not
        sg_group_id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-0bf3a8f73da50ede9" "Name=group-name,Values=${PREFIX}-${machine}" --region us-east-1 --query "SecurityGroups[*].GroupId" --output text)

        # we need to check the sg_id is empty create the new one else ignore
        if [ -z "$sg_group_id" ]; then
            echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Security group not found. Creating security group for ${machine}.${N}"
            sg_group_id=$(aws ec2 create-security-group --group-name "${PREFIX}"-"${machine}" --description "Security group for fdfs ${machine}" --vpc-id vpc-0bf3a8f73da50ede9)
        else
            echo -e "${Y}[WARNING $(date +"%Y-%m-%d %H:%M:%S")] Security group already exists. Security group ID: ${sg_group_id}${N}"
        fi

        # we need to get the sg id once after creation also otherwise it will pass the entire json which will fail the machine creation
        sg_group_id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-0bf3a8f73da50ede9" "Name=group-name,Values=${PREFIX}-${machine}" --region us-east-1 --query "SecurityGroups[*].GroupId" --output text)

        # check the instance before creation
        running_instance_id=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=${PREFIX}-${machine}" "Name=instance-state-name,Values=running" \
            --query "Reservations[*].Instances[*].InstanceId" \
            --output text | tr -d '\r')

        if [ -z "$running_instance_id" ]; then
            echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Instance not found. Creating EC2 machine: ${machine}.${N}"

            aws ec2 run-instances --image-id "${AMI_ID}" --count 1 --instance-type t3.micro --key-name "${KEY_PAIR}" --security-group-ids "${sg_group_id}" "${common_sg}" --subnet-id "${SUBNET_ID}" --no-cli-pager --user-data file://user_data.sh  \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PREFIX}-${machine}}]"

            echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Waiting for instance to become available.${N}"

            sleep 5s

            instance_id=$(aws ec2 describe-instances \
                --filters "Name=tag:Name,Values=${PREFIX}-${machine}" "Name=instance-state-name,Values=running" \
                --query "Reservations[*].Instances[*].InstanceId" \
                --output text)
        else
            instance_id=${running_instance_id}
            echo -e "${Y}[WARNING $(date +"%Y-%m-%d %H:%M:%S")] Machine already exists. Instance ID: ${instance_id}. Skipping creation.${N}"
        fi

        # the machine pvt ip
        pvt_ip=$(aws ec2 describe-instances \
            --instance-ids ${instance_id} \
            --query 'Reservations[*].Instances[*].PrivateIpAddress' \
            --output text | tr -d '\r')

        public_ip=$(aws ec2 describe-instances \
            --instance-ids ${instance_id} \
            --query 'Reservations[*].Instances[*].PublicIpAddress' \
            --output text | tr -d '\r')


        echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Private IP of ${machine}: ${pvt_ip}${N}"

        # update the route53 record
        echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Updating Route53 DNS record: ${PREFIX}-${machine}.${ROOT_DOMAIN}${N}"

        if [ "${PREFIX}-${machine}" = "fdfs-frontend" ]; then
            echo "Matched fdfs-frontend"
            aws route53 change-resource-record-sets \
            --hosted-zone-id "${HOSTED_ZONE_ID}" \
            --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"${PREFIX}-${machine}.${ROOT_DOMAIN}\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"${public_ip}\"}]}}]}"
        else

            echo " we need to update the pvt ip only"
            aws route53 change-resource-record-sets \
            --hosted-zone-id "${HOSTED_ZONE_ID}" \
            --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"${PREFIX}-${machine}.${ROOT_DOMAIN}\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"${pvt_ip}\"}]}}]}"
        fi

        echo -e "${G}[SUCCESS $(date +"%Y-%m-%d %H:%M:%S")] EC2 creation process completed for ${machine}.${N}"

    done
fi

if [ "$1" == "delete" ]; then
    echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Starting EC2 instance deletion.${N}"
    shift

    for machine in "$@"; do

        echo -e "${Y}[WARNING $(date +"%Y-%m-%d %H:%M:%S")] Processing machine deletion: ${machine}${N}"

        instance_id=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=${PREFIX}-${machine}" "Name=instance-state-name,Values=running" \
            --query "Reservations[*].Instances[*].InstanceId" \
            --output text | tr -d '\r')

        # the machine pvt ip
        pvt_ip=$(aws ec2 describe-instances \
            --instance-ids ${instance_id} \
            --query 'Reservations[*].Instances[*].PrivateIpAddress' \
            --output text)

         public_ip=$(aws ec2 describe-instances \
            --instance-ids ${instance_id} \
            --query 'Reservations[*].Instances[*].PublicIpAddress' \
            --output text | tr -d '\r')

        echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Private IP of ${machine}: ${pvt_ip}${N}"

        echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Terminating EC2 instance: ${instance_id}${N}"

        aws ec2 terminate-instances --instance-ids ${instance_id}

        # delete the route53 record
        echo -e "${G}[INFO $(date +"%Y-%m-%d %H:%M:%S")] Deleting Route53 DNS record: ${PREFIX}-${machine}.${ROOT_DOMAIN}${N}"
        if [ "${PREFIX}-${machine}" = "fdfs-frontend" ]; then
            echo "Matched fdfs-frontend"
            aws route53 change-resource-record-sets \
            --hosted-zone-id "${HOSTED_ZONE_ID}" \
            --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"${PREFIX}-${machine}.${ROOT_DOMAIN}\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"${public_ip}\"}]}}]}"
        else

            echo " we need to update the pvt ip only"
            aws route53 change-resource-record-sets \
            --hosted-zone-id "${HOSTED_ZONE_ID}" \
            --change-batch "{\"Changes\":[{\"Action\":\"UPSERT\",\"ResourceRecordSet\":{\"Name\":\"${PREFIX}-${machine}.${ROOT_DOMAIN}\",\"Type\":\"A\",\"TTL\":300,\"ResourceRecords\":[{\"Value\":\"${pvt_ip}\"}]}}]}"
        fi

        echo -e "${G}[SUCCESS $(date +"%Y-%m-%d %H:%M:%S")] EC2 deletion process completed for ${machine}.${N}"

    done
fi