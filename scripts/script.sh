#!/bin/bash

# Updating repository
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -y update

# Installing Apache
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -y install apache2

# Installing MySQL and it's dependencies, Also, setting up root password for MySQL as it will prompt to enter the password during installation

sudo debconf-set-selections <<< 'mysql-server-5.7 mysql-server/root_password password secret'
sudo debconf-set-selections <<< 'mysql-server-5.7 mysql-server/root_password_again password secret'
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -y install mysql-server php7.4-mysql

# Installing PHP and it's dependencies
sudo add-apt-repository ppa:ondrej/php -y 
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -y install php7.4 php7.4-common php7.4-cli
export DEBIAN_FRONTEND=noninteractive 
sudo apt-get -y install php7.4-bcmath php7.4-bz2 php7.4-curl php7.4-intl php7.4-mbstring php7.4-mysql php7.4-readline php7.4-xml php7.4-zip

# Web Server Integration
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -y install php7.4-fpm
sudo a2enconf php7.4-fpm # For Apache only

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -y install libapache2-mod-php7.4

echo vagrant | sudo systemctl reload apache2


# Installing Git
export DEBIAN_FRONTEND=noninteractive
sudo apt-get install git
git --version

# Installing Composer
sudo mkdir /home/vagrant/.composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'c31c1e292ad7be5f49291169c0ac8f683499edddcfd4e42232982d0fd193004208a58ff6f353fde0012d35fdd72bc394') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
echo composer --version
php -r "unlink('composer-setup.php');"
