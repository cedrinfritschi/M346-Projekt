#!/bin/bash

#################################### Prepration

# Enable loggin
set -e
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

# Install wordpress dependencies
apt-get update
apt-get install -y apache2 unzip ghostscript libapache2-mod-php php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip curl

# Make web root directory if not exists
mkdir /var/www/html -p

# Download wordpress
wget "https://wordpress.org/latest.zip" -O /var/www/html/latest.zip

# Decompress the downloaded file
unzip /var/www/html/latest.zip -d /var/www/html

# Move the contents to the web root
mv /var/www/html/wordpress/* /var/www/html/

# Get rid of the zip file and the default Apache page
rm /var/www/html/latest.zip /var/www/html/index.html

# Hand over ownership to www-data
chown www-data:www-data /var/www/html -R
chmod 755 /var/www/html -R #rwxr-xr-x

# Enable Apache modules
a2enmod ssl
a2enmod rewrite

# Create a self-signed certificate (not safe but it's okay, it's a school project... XD YAWN)
mkdir -p /etc/apache2/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/apache2/ssl/apache-selfsigned.key \
    -out /etc/apache2/ssl/apache-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=example.com"

a2ensite default-ssl

# Restart services
systemctl restart apache2
systemctl enable apache2

#################################### Wordpress Installation
# Get the public IP address of the server from EC2 Metadata Service
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Inisialization
DB_NAME="wordpress"
DB_USER="wp-user"
DB_PASSWORD="n3v3r_g0nn4_g1v3_y0u_up"
DB_HOST="<placeholder>"
SITE_URL="http://$PUBLIC_IP"
SITE_TITLE="M365 - WE DID IT!"
ADMIN_USER="mr_secret_admin"
ADMIN_PASSWORD="n3v3r_g0nn4_l3t_Y0u_D0wn"
ADMIN_EMAIL="never_gonna_run_around@and-hurt-you.com"

# Configure wp-config.php
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" /var/www/html/wp-config.php
sed -i "s/username_here/$DB_USER/" /var/www/html/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" /var/www/html/wp-config.php
sed -i "s/localhost/$DB_HOST/" /var/www/html/wp-config.php

# Download WP-CLI to install Wordpress with it
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Install Wordpress
/usr/local/bin/wp core install --url="$SITE_URL" --title="$SITE_TITLE" --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASSWORD" --admin_email="$ADMIN_EMAIL" --path="/var/www/html" --allow-root
/usr/local/bin/wp theme install blockstarter --activate --path="/var/www/html" --allow-root

# Hide Directory listing
touch /var/www/html/wp-content/uploads/index.html
touch /var/www/html/wp-content/themes/blockstarter/index.html

# Customize index page
sed -i 's/Blockstarter/M365 - Project/g' /var/www/html/wp-content/themes/blockstarter/patterns/01-header-image.php
sed -i 's/Experience the magic of full site editing/Ali Jonaghi - Cedrin Fritschi - Sonam Federer/g' /var/www/html/wp-content/themes/blockstarter/patterns/01-header-image.php

# Restart Apache service
systemctl restart apache2
