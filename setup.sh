#!/bin/bash
# ============================================================
# EduLink Quick Setup Script
# Run: chmod +x setup.sh && sudo ./setup.sh
# ============================================================
set -e

DOMAIN="edulink.com"
APP_DIR="/var/www/edulink"
DB_NAME="edulink"
DB_USER="edulink_user"
DB_PASS=$(openssl rand -base64 24)
SOCKET_SECRET=$(openssl rand -base64 32)

echo "╔════════════════════════════════════╗"
echo "║   EduLink Setup Script v1.0        ║"
echo "╚════════════════════════════════════╝"
echo ""

# ── 1. System packages ────────────────────────────────────────
echo "📦 Installing system packages..."
apt update -qq
apt install -y -qq nginx mysql-server redis-server certbot python3-certbot-nginx \
    software-properties-common curl git unzip

# PHP 8.2
add-apt-repository ppa:ondrej/php -y > /dev/null
apt install -y -qq php8.2 php8.2-fpm php8.2-mysql php8.2-redis \
    php8.2-gd php8.2-curl php8.2-mbstring php8.2-xml \
    php8.2-zip php8.2-bcmath php8.2-intl

# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null
apt install -y -qq nodejs

# Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# PM2
npm install -g pm2 > /dev/null

echo "✅ System packages installed"

# ── 2. MySQL setup ────────────────────────────────────────────
echo "🗄️  Setting up MySQL..."
mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Import schema
if [ -f "${APP_DIR}/backend/database/migrations/001_create_all_tables.sql" ]; then
    mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME} < ${APP_DIR}/backend/database/migrations/001_create_all_tables.sql
    echo "✅ Database schema imported"
fi

# ── 3. Laravel backend ────────────────────────────────────────
echo "🐘 Setting up Laravel backend..."
cd ${APP_DIR}/backend

if [ ! -f ".env" ]; then
    cp .env.example .env
    # Update .env with actual values
    sed -i "s/YOUR_STRONG_DB_PASSWORD/${DB_PASS}/" .env
    sed -i "s/YOUR_SOCKET_SECRET_KEY/${SOCKET_SECRET}/" .env
    echo "⚠️  Please edit ${APP_DIR}/backend/.env to add API keys"
fi

composer install --no-dev --optimize-autoloader --quiet
php artisan key:generate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan storage:link

# Permissions
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

echo "✅ Laravel configured"

# ── 4. Real-time server ───────────────────────────────────────
echo "🔌 Setting up Socket.io server..."
cd ${APP_DIR}/realtime

if [ ! -f ".env" ]; then
    cat > .env << EOF
LARAVEL_API=http://localhost:8000
SOCKET_PORT=3001
SOCKET_SECRET=${SOCKET_SECRET}
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
NODE_ENV=production
EOF
fi

npm install --production --quiet
echo "✅ Socket server configured"

# ── 5. Frontend build ─────────────────────────────────────────
echo "⚛️  Building React frontend..."
cd ${APP_DIR}/frontend

if [ ! -f ".env.production" ]; then
    cat > .env.production << EOF
VITE_API_URL=https://${DOMAIN}/api
VITE_SOCKET_URL=https://${DOMAIN}
EOF
fi

npm install --quiet
npm run build
echo "✅ Frontend built"

# ── 6. Nginx ──────────────────────────────────────────────────
echo "🌐 Configuring Nginx..."
mkdir -p /var/log/edulink
cp ${APP_DIR}/docs/nginx.conf /etc/nginx/sites-available/edulink
ln -sf /etc/nginx/sites-available/edulink /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
echo "✅ Nginx configured"

# ── 7. SSL ────────────────────────────────────────────────────
echo "🔒 Setting up SSL..."
certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN} || \
    echo "⚠️  SSL setup failed — set up certbot manually after pointing your domain"

# ── 8. PM2 ────────────────────────────────────────────────────
echo "🚀 Starting services with PM2..."
cd ${APP_DIR}
pm2 start ecosystem.config.js
pm2 startup systemd -u root --hp /root
pm2 save

# ── 9. PHP-FPM ────────────────────────────────────────────────
systemctl enable php8.2-fpm
systemctl restart php8.2-fpm

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║   EduLink setup complete! 🎉                   ║"
echo "╠════════════════════════════════════════════════╣"
echo "║ Site:     https://${DOMAIN}                 ║"
echo "║ DB name:  ${DB_NAME}                           ║"
echo "║ DB user:  ${DB_USER}                         ║"
echo "║ DB pass:  ${DB_PASS}  ║"
echo "╠════════════════════════════════════════════════╣"
echo "║ NEXT STEPS:                                    ║"
echo "║ 1. Edit backend/.env — add API keys            ║"
echo "║ 2. pm2 restart all (after editing .env)        ║"
echo "║ 3. Point your domain DNS A record → this IP    ║"
echo "║ 4. Visit https://${DOMAIN} to get started!  ║"
echo "╚════════════════════════════════════════════════╝"
