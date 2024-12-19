#!/bin/bash

# Initialize colors
YELLOW="\033[33m"
RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"
COLOR_END="\033[0m"

################################### Install AWSCLI if not installed
echo -ne "$YELLOW[i]$COLOR_END Checking if 'awscli' is installed...\r"

awscli_installed=$(which aws)
if [ -z "$awscli_installed" ]; then
	read -p $'\e[34m[?]\e[0m The package "awscli" needs to be installed. Continue? [Y/n] ' install_awscli
	case "$install_awscli" in
		[Yy] | "" )
			sudo apt update;
			curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o ~/awscliv2.zip;
			unzip ~/awscliv2.zip -d ~;
			sudo ~/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update;
			clear;
			echo -e "\e[K$YELLOW[i]$COLOR_END You now have to configure AWSCLI. Refere to this repo's wiki for any questions.";
			mkdir -p ~/.aws;
			read -p "AWS Access Key ID: " aws_access_key_id;
			read -p "AWS Secret Access Key: " aws_secret_access_key;
			read -p "AWS Session token: " aws_session_token;
			read -p "Default region name: " aws_default_region_name;
			read -p "Default output format: " aws_default_output_format;
			echo -e "[default]\nregion = $aws_default_region_name\noutput = $aws_default_output_format" > ~/.aws/config;
			echo -e "[default]\naws_access_key_id = $aws_access_key_id\naws_secret_access_key = $aws_secret_access_key\naws_session_token = $aws_session_token" > ~/.aws/credentials
			clear;
			echo -e "$GREEN[+]$COLOR_END AWSCLI was configured successfully!";
			;;
		* )
			echo -e "$RED[X]$COLOR_END Cannot continue without 'awscli'.";
			exit 1
			;;
	esac
else
	echo -e "\e[K$GREEN[+]$COLOR_END Checking if 'awscli' is installed... $GREEN[OK]$COLOR_END"
fi

#################################### Security groups setup
# Initialization
KEY_NAME="private_key"

echo -ne "$YELLOW[i]$COLOR_END Creating 'wordpress-sg' security group...\r"
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

echo -e "\e[K$GREEN[+]$COLOR_END Creating 'wordpress-sg' security group... $GREEN[OK]$COLOR_END"

echo -ne "$YELLOW[i]$COLOR_END Creating 'mysql-sg' security group...\r"
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

echo -e "\e[K$GREEN[+]$COLOR_END Creating 'mysql-sg' security group... $GREEN[OK]$COLOR_END"

########################################## Start Instances

echo -ne "$YELLOW[i]$COLOR_END Creating key pair...\r"
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem
chmod 600 $KEY_NAME.pem
echo -e "\e[K$GREEN[+]$COLOR_END Creating key pair... $GREEN[OK]$COLOR_END"

# Ask user wether to symmetrically encrypt their private-key
read -p $'\e[34m[?]\e[0m Do you want to protect your private key with a password? [y/N] ' protect_key

case "$protect_key" in
	[Yy] )
		ssh-keygen -p -f "./$KEY_NAME.pem";
		echo -e "$GREEN[+]$COLOR_END The private key is now secured with a password!";
		;;
	* )
		echo -e "$YELLOW[!]$COLOR_END Skipping key protection..."
esac

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

echo -ne "$YELLOW[i]$COLOR_END Waiting for the database instance to start...\r"

aws ec2 wait instance-running --instance-ids $DATABASE_INSTANCE_ID --region 'us-east-1'

echo -e "\e[K$GREEN[+]$COLOR_END Waiting for the database instance to start... $GREEN[OK]$COLOR_END"

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

echo -ne "$YELLOW[i]$COLOR_END Waiting for the Wordpress instance to start...\r"
aws ec2 wait instance-running --instance-ids $WORDPRESS_INSTANCE_ID --region 'us-east-1'
echo -e "\e[K$GREEN[+]$COLOR_END Waiting for the Wordpress instance to start... $GREEN[OK]$COLOR_END"

# Public-IP ermitteln
WORDPRESS_PUBLIC_IP=`aws ec2 describe-instances \
--filters Name=instance-id,Values=$WORDPRESS_INSTANCE_ID \
--query 'Reservations[*].Instances[*].[PublicIpAddress]' \
--output text`

########################################## Print out results
echo -e "$GREEN[+]$COLOR_END Init done."
echo

# Function to calculate the visible length of a string (excluding color codes)
visible_length() {
    local string_no_color=$(echo -e "$1" | sed -E 's/\x1b\[[0-9;]*m//g') # Remove color codes
    echo "${#string_no_color}" # Return the length of the cleaned string
}

# Function to create a table row with alignment
print_row() {
    local content="$1"
    local content_length=$(visible_length "$content") # Get the visible length of the content
    local padding=$((TABLE_WIDTH - content_length - 4)) # Calculate padding dynamically
    echo -e "| $content$(printf ' %.0s' $(seq 1 $padding)) |"
}

# Function to create a separator line
print_separator() {
    echo -e "+$(printf -- '-%.0s' $(seq 1 $((TABLE_WIDTH - 2))))+"
}

# Table width (adjust as needed)
TABLE_WIDTH=75

# Print the table
print_separator
print_row "$GREEN Deployment Summary$COLOR_END"
print_separator
print_row "$GREEN[::]$COLOR_END Instances public IP addresses"
print_row "     - WordPress:$BLUE $WORDPRESS_PUBLIC_IP $COLOR_END"
print_row "     - MySQL    :$BLUE $DATABASE_PUBLIC_IP $COLOR_END"
print_separator
print_row "$GREEN[::]$COLOR_END Visit the following URLs $RED(after 2-5 minutes)$COLOR_END:"
print_row "     - $BLUE http://$WORDPRESS_PUBLIC_IP $COLOR_END"
print_row "     - $BLUE https://$WORDPRESS_PUBLIC_IP $COLOR_END $YELLOW(self-signed certificate)$COLOR_END"
print_separator
print_row "$GREEN[::]$COLOR_END SSH to the server:"
print_row "     - WordPress: ssh$BLUE ubuntu@$WORDPRESS_PUBLIC_IP$COLOR_END -i ./$KEY_NAME.pem"
print_row "     - MySQL    : ssh$BLUE ubuntu@$DATABASE_PUBLIC_IP$COLOR_END -i ./$KEY_NAME.pem"
print_separator
