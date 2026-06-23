module.exports = {
  apps: [
    // ── Laravel Queue Worker ────────────────────────────────
    {
      name:        'edulink-queue',
      script:      'artisan',
      interpreter: 'php',
      args:        'queue:work redis --sleep=3 --tries=3 --max-time=3600',
      cwd:         '/var/www/edulink/backend',
      instances:   1,
      autorestart: true,
      watch:       false,
      max_memory_restart: '256M',
      env: { APP_ENV: 'production' },
    },

    // ── Laravel Scheduler (every minute) ───────────────────
    {
      name:        'edulink-scheduler',
      script:      'artisan',
      interpreter: 'php',
      args:        'schedule:work',
      cwd:         '/var/www/edulink/backend',
      instances:   1,
      autorestart: true,
      watch:       false,
      env: { APP_ENV: 'production' },
    },

    // ── Socket.io Real-time Server ──────────────────────────
    {
      name:        'edulink-socket',
      script:      'server.js',
      cwd:         '/var/www/edulink/realtime',
      instances:   2,
      exec_mode:   'cluster',
      autorestart: true,
      watch:       false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV:     'production',
        SOCKET_PORT:  3001,
        LARAVEL_API:  'http://localhost:8000',
      },
      error_file:  '/var/log/edulink/socket-error.log',
      out_file:    '/var/log/edulink/socket-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
    },
  ],
};
