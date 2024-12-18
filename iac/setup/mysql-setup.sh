#!/bin/bash

###########################
# Author: Cedrin Fritschi #
###########################

# Enable loggin
set -e
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

# Install MySQL Server
apt update
apt install mysql-server -y

# Inisialization
DB_NAME="wordpress"
DB_USER="wp-user"
DB_PASSWORD="n3v3r_g0nn4_g1v3_y0u_up"

# Create Database and the DB User
mysql -e "CREATE DATABASE $DB_NAME;"
mysql -e "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';"
mysql -e "FLUSH PRIVILEGES;"

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'd0nth4ckm3_pl34s3_i_@m_b3gG!ng_u';" # Secure root's password

# Configure MySQL
sed -i "s/bind-address.*/bind-address=0\.0\.0\.0/g" /etc/mysql/mysql.conf.d/mysqld.cnf
sed -i "s/mysqlx-bind-address.*/mysqlx-bind-address=0\.0\.0\.0/g" /etc/mysql/mysql.conf.d/mysqld.cnf

# Restart MySQL service
systemctl restart mysql
