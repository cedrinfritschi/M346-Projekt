#!/bin/bash

################################### Install AWSCLI if not installed
echo "[+] Checking if 'awscli' is installed..."

awscli_installed=$(dpkg-query -s awscli 2>/dev/null)
if [ -z "$awscli_installed" ]; then
	read -p "[?] The package 'awscli' needs to be installed. Continue? [Y/n] " install_awscli
	case "$install_awscli" in
		[Yy] | "" )
			sudo apt update;
			sudo apt install awscli -y;
			clear;
			echo "[i] You now have to configure AWSCLI. Refere to this repo's wiki for any questions.";
			aws configure;;
		* ) echo "[X] Cannot continue without 'awscli'."; exit 1;;
	esac
else
	echo "[+] OK"
fi

#################################### Security groups setup
# Initialization
KEY_NAME="private_key"

echo "[+] Creating 'wordpress-sg' security group..."
# Security-Gruppe erzeugen
WORDPRESS_SG_ID=`aws ec2 create-security-group \
--group-name 'wordpress-sg' \
--description "apache security group" \
--query GroupId \
--output text`

# Open port 80 on the Wordpress Instance
NO_OUTPUT=`aws ec2 authorize-security-group-ingress \
--group-id $WORDPRESS_SG_ID \
--ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0}]'`

# Open port 443 on the Wordpress Instance
NO_OUTPUT=`aws ec2 authorize-security-group-ingress \
--group-id $WORDPRESS_SG_ID \
--ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0}]'`

# Open port 22 on the Wordpress Instance
NO_OUTPUT=`aws ec2 authorize-security-group-ingress \
--group-id $WORDPRESS_SG_ID \
--ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0}]'`

echo "[+] Creating 'mysql-sg' security group..."
# Security-Gruppe erzeugen
MYSQL_SG_ID=`aws ec2 create-security-group \
--group-name 'mysql-sg' \
--description "apache security group" \
--query GroupId \
--output text`

# Open port 3306 on the MySQL instance
NO_OUTPUT=`aws ec2 authorize-security-group-ingress \
--group-id $MYSQL_SG_ID \
--ip-permissions IpProtocol=tcp,FromPort=3306,ToPort=3306,IpRanges='[{CidrIp=0.0.0.0/0}]'`

# Open port 22 on the Wordpress Instance
NO_OUTPUT=`aws ec2 authorize-security-group-ingress \
--group-id $MYSQL_SG_ID \
--ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0}]'`

########################################## Start Instances

echo "[+] Creating key pair..."
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem

# Run an EC2-Instance to host the database
DATABASE_INSTANCE_ID=`aws ec2 run-instances \
--image-id ami-08c40ec9ead489470 --count 1 \
--instance-type t2.micro \
--security-groups mysql-sg \
--iam-instance-profile Name=LabInstanceProfile \
--key-name $KEY_NAME \
--user-data file://setup/mysql-setup.sh \
--query 'Instances[*].InstanceId' \
--output text`

echo "[i] Waiting for the Database instance to start..."
aws ec2 wait instance-running --instance-ids $DATABASE_INSTANCE_ID --region 'us-east-1'
echo "[+] OK"

# Find the database server's public IP address
DATABASE_PUBLIC_IP=`aws ec2 describe-instances \
--filters Name=instance-id,Values=$DATABASE_INSTANCE_ID \
--query 'Reservations[*].Instances[*].[PublicIpAddress]' \
--output text`

sed -i "s/DB_HOST=.*/DB_HOST=\"$DATABASE_PUBLIC_IP\"/g" ./setup/wordpress-setup.sh

# Run an EC2-Instance to host the website
WORDPRESS_INSTANCE_ID=`aws ec2 run-instances \
--image-id ami-08c40ec9ead489470 --count 1 \
--instance-type t2.micro \
--security-groups wordpress-sg \
--iam-instance-profile Name=LabInstanceProfile \
--key-name $KEY_NAME \
--user-data file://setup/wordpress-setup.sh \
--query 'Instances[*].InstanceId' \
--output text`

echo "[i] Waiting for the Wordpress instance to start..."
aws ec2 wait instance-running --instance-ids $WORDPRESS_INSTANCE_ID --region 'us-east-1'
echo "[+] OK"

# Public-IP ermitteln
WORDPRESS_PUBLIC_IP=`aws ec2 describe-instances \
--filters Name=instance-id,Values=$WORDPRESS_INSTANCE_ID \
--query 'Reservations[*].Instances[*].[PublicIpAddress]' \
--output text`

########################################## Print out results
echo "[+] Init done."
echo


# Function to create a table row
print_row() {
    printf "| %-*s |\n" $((TABLE_WIDTH - 4)) "$1"
}

# Function to create a separator line
print_separator() {
    printf "+%s+\n" "$(printf -- "-%.0s" $(seq 1 $((TABLE_WIDTH - 2))))"
}

# Table width (adjust as needed)
TABLE_WIDTH=75

# Print the table
print_separator
print_row "Deployment Summary"
print_separator
print_row "[::] Instances public IP addresses"
print_row "     - WordPress: $WORDPRESS_PUBLIC_IP"
print_row "     - MySQL    : $DATABASE_PUBLIC_IP"
print_separator
print_row "[::] Visit the following URLs (after 2-5 minutes):"
print_row "     - http://$WORDPRESS_PUBLIC_IP"
print_row "     - https://$WORDPRESS_PUBLIC_IP (self-signed certificate)"
print_separator
print_row "[::] SSH to the server:"
print_row "     - WordPress: ssh ubuntu@$WORDPRESS_PUBLIC_IP -i ./$KEY_NAME.pem"
print_row "     - MySQL    : ssh ubuntu@$DATABASE_PUBLIC_IP -i ./$KEY_NAME.pem"
print_separator
