#!/bin/bash

# Initialize colors
YELLOW="\033[33m"
RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[94m"
MAGENTA="\033[95m"
COLOR_END="\033[0m"

# Print banner
echo -e "$MAGENTA █████            $MAGENTA█████████$COLOR_END"
echo -e "$MAGENTA░░███            $MAGENTA███░░░░░███$COLOR_END"
echo -e "$MAGENTA ░███ $BLUE  ██████  $MAGENTA███  $BLUE M $MAGENTA░░░ $COLOR_END"
echo -e "$MAGENTA ░███ $BLUE ░░░░░███$MAGENTA░███  $BLUE 3 $MAGENTA       $COLOR_END"
echo -e "$MAGENTA ░███ $BLUE  ███████$MAGENTA░███  $BLUE 4 $MAGENTA       $COLOR_END"
echo -e "$MAGENTA ░███ $BLUE ███░░███$MAGENTA░░███ $BLUE 6 $MAGENTA ███$COLOR_END"
echo -e "$MAGENTA █████$BLUE░░████████$MAGENTA░░█████████$COLOR_END"
echo -e "$MAGENTA░░░░░ $BLUE ░░░░░░░░$MAGENTA  ░░░░░░░░░$COLOR_END"
echo

set -e

# Variables
REGION="us-east-1"
KEY_NAME="private_key"
MYSQL_SECURITY_GROUP="mysql-sg"
WORDPRESS_SECURITY_GROUP="wordpress-sg"

# Function to terminate all running instances
terminate_all_instances() {
    echo -e "$YELLOW[i]$COLOR_END Finding all running instances to terminate..."

    # Get all running instances
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text --region $REGION)

    if [ -z "$INSTANCE_IDS" ]; then
        echo -e "$YELLOW[!]$COLOR_END No running instances found. Skipping termination."
    else
        echo -e "$GREEN[+]$COLOR_END Terminating instances: $INSTANCE_IDS"
        aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $REGION
        echo -e "$YELLOW[i]$COLOR_END Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $REGION
        echo -e "$GREEN[+]$COLOR_END Instances terminated successfully."
    fi
}

# Function to delete a security group
delete_security_group() {
    local SECURITY_GROUP_NAME=$1

    echo -e "$YELLOW[i]$COLOR_END Attempting to delete security group: $SECURITY_GROUP_NAME"

    # Get the security group ID
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
        --query "SecurityGroups[*].GroupId" \
        --output text --region $REGION)

    if [ -z "$SG_ID" ]; then
        echo -e "$YELLOW[!]$COLOR_END Security group $SECURITY_GROUP_NAME does not exist. Skipping."
        return
    fi

    # Check for dependencies (network interfaces)
    DEPENDENCIES=$(aws ec2 describe-network-interfaces \
        --filters Name=group-id,Values=$SG_ID \
        --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text --region $REGION)

    if [ -n "$DEPENDENCIES" ]; then
        echo -e "$YELLOW[!]$COLOR_END Security group $SECURITY_GROUP_NAME has dependencies. Cleaning up dependencies..."
        for NI in $DEPENDENCIES; do
            echo -e "$YELLOW[i]$COLOR_END Identifying resource using network interface $NI..."
            ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --network-interface-ids $NI --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text)

            if [ "$ATTACHMENT_ID" != "None" ]; then
                echo -e "$GREEN[+]$COLOR_END Detaching network interface $NI (Attachment ID: $ATTACHMENT_ID)..."
                aws ec2 detach-network-interface --attachment-id $ATTACHMENT_ID --region $REGION
            fi

            echo -e "$GREEN[+]$COLOR_END Deleting network interface $NI..."
            aws ec2 delete-network-interface --network-interface-id $NI --region $REGION
        done
    fi

    echo -e "$YELLOW[i]$COLOR_END Deleting security group $SECURITY_GROUP_NAME (ID: $SG_ID)..."
    aws ec2 delete-security-group --group-id $SG_ID --region $REGION
    echo -e "$GREEN[+]$COLOR_END Security group $SECURITY_GROUP_NAME deleted successfully."
}

# Function to delete key pair
delete_key_pair() {
    echo -e "$YELLOW[i]$COLOR_END Deleting key pair $KEY_NAME..."
    aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION

    if [ -f "$KEY_NAME.pem" ]; then
        rm -f "$KEY_NAME.pem"
        echo -e "$GREEN[+]$COLOR_END Local key file $KEY_NAME.pem removed."
    fi

    echo -e "$GREEN[+]$COLOR_END Key pair $KEY_NAME deleted successfully."
}

# Run cleanup steps
terminate_all_instances # Ensure all running instances are terminated
delete_security_group $MYSQL_SECURITY_GROUP # Delete MySQL security group first
delete_security_group $WORDPRESS_SECURITY_GROUP # Then delete WordPress security group
delete_key_pair

sed -i "s/DB_HOST=.*/DB_HOST=\"<placeholder>\"/g" ./setup/wordpress-setup.sh

echo
echo -e "$GREEN[::]$COLOR_END Cleanup process completed successfully!"
