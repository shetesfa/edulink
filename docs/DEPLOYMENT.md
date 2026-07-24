# EduLink — Complete Deployment Guide

## System Requirements (Your Server)
- Ubuntu 22.04 LTS (recommended)
- PHP 8.2 + Composer
- MySQL 8.0
- Node.js 20+
- Redis 7+
- Nginx
- SSL certificate (Let's Encrypt — free)

---

## STEP 1 — Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install PHP 8.2
sudo add-apt-repository ppa:ondrej/php -y
sudo apt install php8.2 php8.2-fpm php8.2-mysql php8.2-redis \
  php8.2-gd php8.2-curl php8.2-mbstring php8.2-xml \
  php8.2-zip php8.2-bcmath -y

# Install MySQL
sudo apt install mysql-server -y
sudo mysql_secure_installation

# Install Redis
sudo apt install redis-server -y

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs -y

# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install Nginx
sudo apt install nginx -y

# Install PM2 (process manager for Node.js)
sudo npm install -g pm2

# Install Certbot (free SSL)
sudo apt install certbot python3-certbot-nginx -y
```

---

## STEP 2 — MySQL Database Setup

```sql
-- Run as root in MySQL
CREATE DATABASE edulink CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'edulink_user'@'localhost' IDENTIFIED BY 'YOUR_STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON edulink.* TO 'edulink_user'@'localhost';
FLUSH PRIVILEGES;
```

```bash
# Import the schema
mysql -u edulink_user -p edulink < backend/database/migrations/001_create_all_tables.sql
```

---

## STEP 3 — Backend (Laravel) Setup

```bash
cd /var/www/edulink/backend

# Install PHP dependencies
composer install --no-dev --optimize-autoloader

# Copy and edit environment file
cp .env.example .env
nano .env
# → Fill in: DB_PASSWORD, GOOGLE_CLIENT_ID, GEMINI_API_KEY, GROQ_API_KEY, etc.

# Generate app key
php artisan key:generate

# Run migrations
php artisan migrate

# Set storage permissions
chmod -R 775 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache

# Optimize
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Create storage symlink (for file uploads)
php artisan storage:link

# Start queue worker
pm2 start "php artisan queue:work redis --sleep=3 --tries=3" --name edulink-queue
pm2 save
```

---

## STEP 4 — Real-time Server (Node.js) Setup

```bash
cd /var/www/edulink/realtime

# Install dependencies
npm install --production

# Create .env file
cat > .env << EOF
LARAVEL_API=http://localhost:8000
SOCKET_PORT=3001
SOCKET_SECRET=YOUR_SOCKET_SECRET_HERE
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
EOF

# Start with PM2
pm2 start server.js --name edulink-socket
pm2 save
pm2 startup
```

---

## STEP 5 — Frontend (React/PWA) Build

```bash
cd /var/www/edulink/frontend

# Install dependencies
npm install

# Create environment file
cat > .env.production << EOF
VITE_API_URL=https://edulink.com/api
VITE_SOCKET_URL=https://edulink.com
EOF

# Build for production
npm run build

# Output is in: frontend/dist/
```

---

## STEP 6 — Nginx Configuration

```nginx
# /etc/nginx/sites-available/edulink

# Main web app + API
server {
    listen 80;
    server_name edulink.com www.edulink.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name edulink.com www.edulink.com;

    ssl_certificate     /etc/letsencrypt/live/edulink.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/edulink.com/privkey.pem;

    # Frontend (React PWA)
    root /var/www/edulink/frontend/dist;
    index index.html;

    # API → Laravel
    location /api {
        try_files $uri $uri/ @php;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME /var/www/edulink/backend/public/index.php;
        include fastcgi_params;
    }

    # Laravel storage files
    location /storage {
        alias /var/www/edulink/backend/storage/app/public;
    }

    # WebSocket (Socket.io) → Node.js
    location /socket.io {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }

    # Jitsi video meetings (proxy to meet.jit.si)
    location /meeting-proxy {
        proxy_pass https://meet.jit.si;
        proxy_set_header Host meet.jit.si;
    }

    # React Router (SPA fallback)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "no-referrer-when-downgrade";
    add_header Content-Security-Policy "default-src 'self' https: wss:; script-src 'self' 'unsafe-inline' https:; style-src 'self' 'unsafe-inline' https:;";

    # File upload limit
    client_max_body_size 100M;
}
```

```bash
# Enable site and get SSL
sudo ln -s /etc/nginx/sites-available/edulink /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
sudo certbot --nginx -d edulink.com -d www.edulink.com
```

---

## STEP 7 — Mobile App (Android APK)

```bash
cd /var/www/edulink/frontend

# Install Capacitor
npm install @capacitor/core @capacitor/cli @capacitor/android @capacitor/ios
npm install @capacitor/push-notifications @capacitor/splash-screen @capacitor/status-bar

# Build frontend first
npm run build

# Initialize Capacitor
npx cap init EduLink com.edulink.app --web-dir dist

# Add Android platform
npx cap add android

# Copy web assets into Android project
npx cap copy android

# Sync plugins
npx cap sync android

# Build APK (requires Android Studio or command line tools)
cd android && ./gradlew assembleRelease
# → APK output: android/app/build/outputs/apk/release/app-release.apk

# For iOS (macOS + Xcode required)
npx cap add ios
npx cap copy ios
npx cap sync ios
npx cap open ios
# → Build and sign in Xcode
```

---

## STEP 8 — AI API Keys (All Free)

Get these free API keys and add to backend/.env:

| Provider    | Free Tier         | Get Key At                          |
|-------------|-------------------|-------------------------------------|
| Gemini      | 1,500 req/day     | https://makersuite.google.com       |
| Groq        | 14,400 req/day    | https://console.groq.com            |
| Cohere      | 1,000 req/day     | https://dashboard.cohere.com        |
| Mistral     | 1,000 req/day     | https://console.mistral.ai          |
| Together AI | $1 free credit    | https://api.together.xyz            |
| HuggingFace | Unlimited (slow)  | https://huggingface.co/settings/tokens |

---

## STEP 9 — Google OAuth Setup

1. Go to https://console.cloud.google.com
2. Create a new project → "EduLink"
3. Enable "Google+ API" and "Google Identity"
4. Create OAuth 2.0 credentials (Web application)
5. Add authorized redirect URI: `https://edulink.com/api/auth/google/callback`
6. Copy Client ID and Secret to .env

---

## STEP 10 — Firebase Push Notifications (Free)

1. Go to https://console.firebase.google.com
2. Create project → "EduLink"
3. Add web app → get config
4. Go to Project Settings → Service Accounts → Generate private key
5. Save the JSON file as: `backend/storage/app/firebase-credentials.json`
6. Add FIREBASE_PROJECT_ID to .env

---

## Quick PM2 Process Management

```bash
pm2 list                    # See all processes
pm2 logs edulink-socket     # View socket server logs
pm2 restart edulink-socket  # Restart socket server
pm2 restart edulink-queue   # Restart queue worker
pm2 monit                   # Monitor all processes
```

---

## Useful Commands

```bash
# Clear Laravel caches after .env changes
php artisan config:clear && php artisan cache:clear && php artisan config:cache

# Check Laravel logs
tail -f /var/www/edulink/backend/storage/logs/laravel.log

# Check socket server logs
pm2 logs edulink-socket

# Monitor Redis
redis-cli monitor

# Check Nginx errors
tail -f /var/log/nginx/error.log
```

---

## Domain Setup (DNS)

Add these records at your domain registrar:
```
Type  Name    Value
A     @       YOUR_SERVER_IP
A     www     YOUR_SERVER_IP
```

---

## Architecture Summary

```
Browser/PWA/Android
    ↓ HTTPS
Nginx (port 443)
    ├── /api     → Laravel (PHP-FPM, port 8000)
    ├── /socket.io → Node.js Socket.io (port 3001)
    └── /*       → React SPA (dist/index.html)

Laravel ← → MySQL (data)
Laravel ← → Redis (cache, queues, sessions)
Node.js ← → Redis (online users, pub/sub)
Laravel → → Firebase (push notifications)
Laravel → → AI providers (Gemini, Groq, etc.)
```

---

Total estimated setup time: **2-3 hours**
Monthly server cost: **~$10-20** (DigitalOcean/Hetzner)
AI cost: **$0** (all free tiers)
