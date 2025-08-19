#!/bin/bash

# Base installation
sudo apt update
sudo apt install -y nginx php php-fpm php-mysql mysql-server curl unzip varnish

# Setup WordPress or Laravel
if [ "$1" == "wordpress" ]; then
  echo "Installing WordPress..."
  curl -O https://wordpress.org/latest.tar.gz
  tar xzvf latest.tar.gz
  sudo mv wordpress /var/www/html/
  sudo chown -R www-data:www-data /var/www/html/wordpress

elif [ "$1" == "laravel" ]; then
  echo "Installing Laravel..."
  curl -sS https://getcomposer.org/installer | php
  sudo mv composer.phar /usr/local/bin/composer
  composer create-project --prefer-dist laravel/laravel /var/www/html/laravel
  sudo chown -R www-data:www-data /var/www/html/laravel
fi

# Restart services
sudo systemctl restart nginx
sudo systemctl restart php7.4-fpm || sudo systemctl restart php8.1-fpm
