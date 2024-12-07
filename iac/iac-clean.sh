#!/bin/bash

set -e

# Variables
REGION="us-east-1"
KEY_NAME="wordpress-key"
MYSQL_SECURITY_GROUP="mysql-sg"
WORDPRESS_SECURITY_GROUP="wordpress-sg"

# Function to terminate all running instances
terminate_all_instances() {
    echo "Finding all running instances to terminate..."

    # Get all running instances
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text --region $REGION)

    if [ -z "$INSTANCE_IDS" ]; then
        echo "No running instances found. Skipping termination."
    else
        echo "Terminating instances: $INSTANCE_IDS"
        aws ec2 terminate-instances --instance-ids $INSTANCE_IDS --region $REGION
        echo "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS --region $REGION
        echo "Instances terminated successfully."
    fi
}

# Function to delete a security group
delete_security_group() {
    local SECURITY_GROUP_NAME=$1

    echo "Attempting to delete security group: $SECURITY_GROUP_NAME"

    # Get the security group ID
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
        --query "SecurityGroups[*].GroupId" \
        --output text --region $REGION)

    if [ -z "$SG_ID" ]; then
        echo "Security group $SECURITY_GROUP_NAME does not exist. Skipping."
        return
    fi

    # Check for dependencies (network interfaces)
    DEPENDENCIES=$(aws ec2 describe-network-interfaces \
        --filters Name=group-id,Values=$SG_ID \
        --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text --region $REGION)

    if [ -n "$DEPENDENCIES" ]; then
        echo "Security group $SECURITY_GROUP_NAME has dependencies. Cleaning up dependencies..."
        for NI in $DEPENDENCIES; do
            echo "Identifying resource using network interface $NI..."
            ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --network-interface-ids $NI --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text)

            if [ "$ATTACHMENT_ID" != "None" ]; then
                echo "Detaching network interface $NI (Attachment ID: $ATTACHMENT_ID)..."
                aws ec2 detach-network-interface --attachment-id $ATTACHMENT_ID --region $REGION
            fi

            echo "Deleting network interface $NI..."
            aws ec2 delete-network-interface --network-interface-id $NI --region $REGION
        done
    fi

    echo "Deleting security group $SECURITY_GROUP_NAME (ID: $SG_ID)..."
    aws ec2 delete-security-group --group-id $SG_ID --region $REGION
    echo "Security group $SECURITY_GROUP_NAME deleted successfully."
}

# Function to delete key pair
delete_key_pair() {
    echo "Deleting key pair $KEY_NAME..."
    aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION

    if [ -f "$KEY_NAME.pem" ]; then
        rm -f "$KEY_NAME.pem"
        echo "Local key file $KEY_NAME.pem removed."
    fi

    echo "Key pair $KEY_NAME deleted successfully."
}

# Run cleanup steps
terminate_all_instances # Ensure all running instances are terminated
delete_security_group $MYSQL_SECURITY_GROUP # Delete MySQL security group first
delete_security_group $WORDPRESS_SECURITY_GROUP # Then delete WordPress security group
delete_key_pair

echo "Cleanup process completed successfully!"

