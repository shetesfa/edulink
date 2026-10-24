@echo off
title EduLink Firewall Setup (Run as Admin)
echo ============================================
echo   EduLink - Opening Firewall Ports
echo ============================================
echo.
echo This needs to run as Administrator once.
echo.

echo Opening port 3000 (Web / Phone browser)...
netsh advfirewall firewall delete rule name="EduLink Web" >nul 2>&1
netsh advfirewall firewall add rule name="EduLink Web" dir=in action=allow protocol=TCP localport=3000

echo Opening port 8000 (Backend API)...
netsh advfirewall firewall delete rule name="EduLink API" >nul 2>&1
netsh advfirewall firewall add rule name="EduLink API" dir=in action=allow protocol=TCP localport=8000

echo Opening port 8080 (WebSocket Reverb)...
netsh advfirewall firewall delete rule name="EduLink WebSocket" >nul 2>&1
netsh advfirewall firewall add rule name="EduLink WebSocket" dir=in action=allow protocol=TCP localport=8080

echo.
echo ============================================
echo   Firewall rules added successfully!
echo   Your phone can now connect to this PC.
echo ============================================
echo.
pause
