#|/bin/bash

# Initialization
KEY_NAME="wordpress-key"

echo "[+] Creating 'wordpress-sg' security group..."
# Security-Gruppe erzeugen
SECGROUP_ID=`aws ec2 create-security-group \
--group-name 'wordpress-sg' \
--description "apache security group" \
--query GroupId \
--output text`

echo "[+] Creating key pair..."
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem

# Open port 80
NO_OUTPUT=`aws ec2 authorize-security-group-ingress \
--group-id $SECGROUP_ID \
--ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0}]'`

# Open port 443
NO_OUTPUT=`aws ec2 authorize-security-group-ingress \
--group-id $SECGROUP_ID \
--ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0}]'`

# Open port 22
NO_OUTPUT=`aws ec2 authorize-security-group-ingress \
--group-id $SECGROUP_ID \
--ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0}]'`


# EC2-Instanz erzeugen, Apache Webserver installieren
INSTANCE_ID=`aws ec2 run-instances \
--image-id ami-08c40ec9ead489470 --count 1 \
--instance-type t2.micro \
--security-groups wordpress-sg \
--iam-instance-profile Name=LabInstanceProfile \
--key-name $KEY_NAME \
--user-data file://wordpress-setup.sh \
--query 'Instances[*].InstanceId' \
--output text`

echo "[i] Waiting for the instance to start..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region us-east-1

# Public-IP ermitteln
PUBLIC_IP=`aws ec2 describe-instances \
--filters Name=instance-id,Values=$INSTANCE_ID \
--query 'Reservations[*].Instances[*].[PublicIpAddress]' \
--output text`

# URL ausgeben
echo "[+] Init done."
echo
echo "[.::.] Wait for 5 minutes and then visit: http://$PUBLIC_IP or https://$PUBLIC_IP (self-signed certificate)"
echo "[.::.] SSH to the server using: ssh -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP -i ./wordpress-key.pem"
