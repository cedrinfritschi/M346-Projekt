#|/bin/bash

KEY_NAME="wordpress-key"

# Security-Gruppe erzeugen
SECGROUP_ID=`aws ec2 create-security-group \
--group-name 'wordpress-sg' \
--description "apache security group" \
--query GroupId \
--output text`

echo "Creating key pair..."
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem

# Port 80 öffnen
NO_OUTPUT=`aws ec2 authorize-security-group-ingress \
--group-id $SECGROUP_ID \
--ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0}]'`

# Port 22 öffnen
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
--user-data '#!/bin/bash
    sudo apt-get update
    sudo apt-get install -y apache2 unzip ghostscript libapache2-mod-php mysql-server php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip
    sudo mkdir /var/www/html -p
    sudo wget "https://wordpress.org/latest.zip" -O /var/www/html/latest.zip
    sudo unzip /var/www/html/latest.zip
    sudo rm /var/www/html/latest.zip
    sudo systemctl restart apache2
    sudo systemctl enable apache2' \
--query 'Instances[*].InstanceId' \
--output text`

echo "Waiting for the instance to start..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region us-east-1

SSH_COMMANDS=$(cat << 'EOF'
#!/bin/bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Apache, MySQL, PHP
sudo apt install -y apache2 mysql-server php php-mysql libapache2-mod-php php-cli php-cgi php-gd wget unzip libapache2-mod-wsgi python-dev

sudo a2enmod wsgi
sudo systemctl reload apache2

# Secure MySQL
sudo mysql_secure_installation

# Create MySQL Database and User
DB_NAME="wordpress_db"
DB_USER="wordpress_user"
DB_PASSWORD="password"

sudo mysql -u root <<END
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
END

# Download and set up WordPress
wget https://wordpress.org/latest.tar.gz
tar -xvzf latest.tar.gz
sudo mv wordpress /var/www/html/
sudo chown -R www-data:www-data /var/www/html/wordpress
sudo chmod -R 755 /var/www/html/wordpress

# Configure Apache for WordPress
sudo cat <<END > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/wordpress
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
END

sudo a2ensite wordpress.conf
sudo a2enmod rewrite
sudo systemctl restart apache2

echo "WordPress installation completed. Please configure via web browser."
EOF
)

# Public-IP ermitteln
PUBLIC_IP=`aws ec2 describe-instances \
--filters Name=instance-id,Values=$INSTANCE_ID \
--query 'Reservations[*].Instances[*].[PublicIpAddress]' \
--output text`

echo "$SSH_COMMANDS" | ssh -o "StrictHostKeyChecking=no" -i "wordpress-key.pem" ubuntu@$PUBLIC_IP

# URL ausgeben
echo "http://$PUBLIC_IP"
