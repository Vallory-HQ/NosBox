#!/bin/bash

# Updating repository

sudo apt-get -y update

# Installing Apache

sudo apt-get -y install apache2

# Installing MySQL and it's dependencies, Also, setting up root password for MySQL as it will prompt to enter the password during installation

sudo debconf-set-selections <<< 'mysql-server-5.7 mysql-server/root_password password secret'
sudo debconf-set-selections <<< 'mysql-server-5.7 mysql-server/root_password_again password secret'
sudo apt-get -y install mysql-server php7.4-mysql

# Installing PHP and it's dependencies
sudo add-apt-repository ppa:ondrej/php -y 
sudo apt-get update

sudo apt-get -y install php7.4 php7.4-common php7.4-cli 
sudo apt-get -y install php7.4-bcmath php7.4-bz2 php7.4-curl php7.4-intl php7.4-mbstring php7.4-mysql php7.4-readline php7.4-xml php7.4-zip

# Web Server Integration
sudo apt-get -y install php7.4-fpm
sudo a2enconf php7.4-fpm # For Apache only

sudo apt-get -y install libapache2-mod-php7.4

echo vagrant | sudo systemctl reload apache2
