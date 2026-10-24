@echo off
title EduLink Master Server Controller
color 0A
cls

echo ====================================================================
echo                 EDULINK MASTER SERVER CONTROLLER
echo ====================================================================
echo.

:: ── Set Paths ───────────────────────────────────────────────────────────────
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%flutter_app"
set "BACKEND_DIR=%SCRIPT_DIR%backend"

:: ── Step 1: Kill old PHP zombie processes to free ports ──────────────────────
echo [STEP 1] Freeing ports 8000, 3000 and 8080 (terminating old php processes)...
taskkill /F /IM php.exe >nul 2>&1
echo        Ports cleared.
echo.

:: ── Step 2: Check PHP installation ──────────────────────────────────────────
echo [STEP 2] Checking PHP installation...
php --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ================================================================
    echo   ERROR: PHP is not installed or not in PATH!
    echo   Please install PHP 8.2+ and add it to your system PATH.
    echo ================================================================
    pause
    exit /b 1
)
echo        PHP found and ready.
echo.

:: ── Step 3: Detect IP using get_ip.ps1 ────────────────────────────────────
echo [STEP 3] Detecting network IP address...

for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%get_ip.ps1"') do set "LOCAL_IP=%%i"
for /f "tokens=1" %%a in ("%LOCAL_IP%") do set "LOCAL_IP=%%a"
if "%LOCAL_IP%"=="" set "LOCAL_IP=127.0.0.1"

echo        Detected IP: %LOCAL_IP%
echo.

:: ── Step 4: Update all config files with current IP ─────────────────────────
echo [STEP 4] Updating backend and Flutter configuration files...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%update_config.ps1" -NewIP "%LOCAL_IP%"
echo        Configuration updated.
echo.

:: ── Step 5: Add Windows Firewall Rules ──────────────────────────────────────
echo [STEP 5] Configuring Windows Firewall (ports 3000, 8000, 8080)...
netsh advfirewall firewall delete rule name="EduLink Web" >nul 2>&1
netsh advfirewall firewall add rule name="EduLink Web" dir=in action=allow protocol=TCP localport=3000 >nul 2>&1
netsh advfirewall firewall delete rule name="EduLink API" >nul 2>&1
netsh advfirewall firewall add rule name="EduLink API" dir=in action=allow protocol=TCP localport=8000 >nul 2>&1
netsh advfirewall firewall delete rule name="EduLink WebSocket" >nul 2>&1
netsh advfirewall firewall add rule name="EduLink WebSocket" dir=in action=allow protocol=TCP localport=8080 >nul 2>&1
echo        Firewall rules configured.
echo.

:: ── Step 6: Prepare Laravel Backend ─────────────────────────────────────────
echo [STEP 6] Preparing Laravel backend (clearing caches)...
cd /d "%BACKEND_DIR%"
php artisan config:clear >nul 2>&1
php artisan cache:clear >nul 2>&1
php artisan route:clear >nul 2>&1
php artisan migrate --force >nul 2>&1
echo        Laravel ready.
echo.

:: ── Step 7: Start Reverb WebSocket Server ───────────────────────────────────
echo [STEP 7] Starting Reverb WebSocket Server (Port 8080)...
start "EduLink [1/3] Reverb WebSocket" /min cmd /k "cd /d "%BACKEND_DIR%" && php artisan reverb:start --host=0.0.0.0 --port=8080"
timeout /t 3 >nul
echo        Reverb WebSocket running on ws://%LOCAL_IP%:8080
echo.

:: ── Step 8: Start Web Frontend Server ───────────────────────────────────────
echo [STEP 8] Starting Web Frontend Server (Port 3000)...
if not exist "%PROJECT_DIR%\build\web\index.html" (
    echo        No web build found - building Flutter Web now...
    echo        Please wait, this takes a few minutes the first time...
    cd /d "%PROJECT_DIR%"
    flutter build web --release
    if %errorlevel% neq 0 (
        echo.
        echo   ERROR: Flutter web build FAILED! Cannot start web server.
        pause
        exit /b 1
    )
    echo        Flutter web build complete!
)
start "EduLink [2/3] Web Frontend" /min cmd /k "cd /d "%PROJECT_DIR%" && php -S 0.0.0.0:3000 -t build\web"
timeout /t 3 >nul
echo        Web Server running at http://%LOCAL_IP%:3000
echo.

:: ── Step 9: Start Laravel Backend API Server ────────────────────────────────
echo [STEP 9] Starting Laravel Backend API Server (Port 8000)...
start "EduLink [3/3] Backend API" /min cmd /k "cd /d "%BACKEND_DIR%" && php artisan serve --host=0.0.0.0 --port=8000"
timeout /t 5 >nul
echo        Backend API running at http://%LOCAL_IP%:8000
echo.

:: ── Step 10: Open Browser ────────────────────────────────────────────────────
echo [STEP 10] Opening browser...
start http://localhost:3000
echo.

timeout /t 2 >nul

:: ── System Status Dashboard ──────────────────────────────────────────────────
cls
echo ====================================================================
echo          EDULINK IS FULLY RUNNING!   IP: %LOCAL_IP%
echo ====================================================================
echo.
echo   [ON THIS PC]
echo   Web App          :  http://localhost:3000
echo   Backend API      :  http://localhost:8000/api
echo.
echo   [FROM PHONE or TABLET (must be on SAME Wi-Fi)]
echo   Web App          :  http://%LOCAL_IP%:3000
echo   API Endpoint     :  http://%LOCAL_IP%:8000/api
echo   WebSocket Chat   :  ws://%LOCAL_IP%:8080
echo.
echo   [ALL RUNNING SERVICES]
echo   1. Reverb WS     :  ws://%LOCAL_IP%:8080
echo   2. Web Frontend  :  http://%LOCAL_IP%:3000
echo   3. Backend API   :  http://%LOCAL_IP%:8000
echo.
echo ====================================================================
echo   Leave this window open. Close all EduLink windows to stop.
echo ====================================================================
echo.
echo   TROUBLESHOOTING:
echo   - Phone can't connect? Make sure phone is on SAME Wi-Fi as this PC.
echo   - Still can't connect? Run SETUP_FIREWALL.bat as Administrator.
echo   - IP changed? Just run START_SERVER.bat again - it auto-updates!
echo.
pause
