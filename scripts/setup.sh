sudo tee /root/setup.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euxo pipefail

###################################
# 0) Choose app type (no TF templating)
###################################
# Priority: CLI arg > env APP_TYPE > GCE metadata > default "wordpress"
APP_TYPE="${1:-${APP_TYPE:-}}"

# Read from GCE instance metadata if still empty
if [[ -z "${APP_TYPE}" ]]; then
  if curl -fsS -H 'Metadata-Flavor: Google' http://metadata.google.internal >/dev/null 2>&1; then
    APP_TYPE="$(curl -fsS -H 'Metadata-Flavor: Google' \
      'http://metadata.google.internal/computeMetadata/v1/instance/attributes/app_type' || true)"
  fi
fi

APP_TYPE="${APP_TYPE:-wordpress}"
if [[ "${APP_TYPE}" != "wordpress" && "${APP_TYPE}" != "laravel" ]]; then
  echo "Invalid APP_TYPE '${APP_TYPE}'. Must be 'wordpress' or 'laravel'." >&2
  exit 2
fi

export DEBIAN_FRONTEND=noninteractive
retry() { for i in {1..10}; do "$@" && break || { echo "retry $i"; sleep 6; }; done; }

###################################
# 1) Base OS
###################################
retry apt-get update -y
retry apt-get install -y ca-certificates curl unzip git lsb-release gnupg software-properties-common

###################################
# 2) Nginx + PHP 8.3 + MySQL + Varnish
###################################
retry apt-get install -y \
  nginx \
  mysql-server \
  varnish \
  php8.3 php8.3-fpm php8.3-cli \
  php8.3-mysql php8.3-zip php8.3-curl php8.3-mbstring php8.3-xml php8.3-gd php8.3-intl php8.3-bcmath

PHPFPM_UNIT="php8.3-fpm"
PHP_SOCK="/run/php/php8.3-fpm.sock"

systemctl enable --now "${PHPFPM_UNIT}"
systemctl enable --now nginx
systemctl enable --now varnish

mkdir -p /var/www/html
chown -R www-data:www-data /var/www/html

###################################
# 3) App install
###################################
if [[ "${APP_TYPE}" == "wordpress" ]]; then
  echo "Installing WordPress…"
  cd /tmp
  retry curl -fsSLO https://wordpress.org/latest.tar.gz
  tar xzf latest.tar.gz
  rm -rf /var/www/html/wordpress
  mv wordpress /var/www/html/wordpress

  chown -R www-data:www-data /var/www/html/wordpress
  find /var/www/html/wordpress -type d -exec chmod 755 {} \;
  find /var/www/html/wordpress -type f -exec chmod 644 {} \;

  # Nginx site for WordPress
  cat >/etc/nginx/sites-available/wordpress <<NGINX
server {
  listen 80;
  server_name _;
  root /var/www/html/wordpress;
  index index.php index.html;

  location / {
    try_files \$uri \$uri/ /index.php?\$args;
  }

  location ~ \.php\$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:${PHP_SOCK};
  }

  location ~* \.(jpg|jpeg|gif|png|css|js|ico|webp|svg|woff2?)\$ {
    expires 30d;
    access_log off;
  }
}
NGINX

  ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/default

else
  echo "Installing Laravel…"
  cd /tmp
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php composer-setup.php --quiet
  mv composer.phar /usr/local/bin/composer
  rm -f composer-setup.php

  rm -rf /var/www/html/laravel
  sudo -u www-data composer create-project --prefer-dist laravel/laravel /var/www/html/laravel

  # Permissions
  chown -R www-data:www-data /var/www/html/laravel
  find /var/www/html/laravel -type d -exec chmod 755 {} \;
  find /var/www/html/laravel -type f -exec chmod 644 {} \;
  chmod -R 775 /var/www/html/laravel/storage /var/www/html/laravel/bootstrap/cache
  chgrp -R www-data /var/www/html/laravel/storage /var/www/html/laravel/bootstrap/cache

  # Generate APP_KEY
  sudo -u www-data bash -lc 'cd /var/www/html/laravel && php artisan key:generate'

  # Nginx site for Laravel
  cat >/etc/nginx/sites-available/laravel <<NGINX
server {
  listen 80;
  server_name _;
  root /var/www/html/laravel/public;
  index index.php index.html;

  location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
  }

  location ~ \.php\$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:${PHP_SOCK};
  }

  location ~* \.(jpg|jpeg|gif|png|css|js|ico|webp|svg|woff2?)\$ {
    expires 30d;
    access_log off;
  }
}
NGINX

  ln -sf /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/default
fi

###################################
# 4) Finalize services
###################################
nginx -t
systemctl reload nginx || systemctl restart nginx
systemctl restart "${PHPFPM_UNIT}" || true
systemctl restart varnish || true

echo "✅ Setup complete for ${APP_TYPE} with PHP 8.3 (Varnish installed)"
EOF

sudo chmod +x /root/setup.sh
# Let it auto-detect from metadata (which you set via Terraform)
sudo /root/setup.sh
