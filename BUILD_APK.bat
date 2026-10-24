@echo off
echo ========================================
echo        EduLink APK Build Script
echo ========================================
echo.

set "SCRIPT_DIR=%~dp0"
set "FLUTTER_DIR=%SCRIPT_DIR%flutter_app"
set "OUTPUT_APK=%SCRIPT_DIR%EduLink-App.apk"

cd /d "%FLUTTER_DIR%"

echo [1/3] Checking Flutter installation...
call flutter --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter from https://flutter.dev
    pause
    exit /b 1
)
echo Flutter found successfully.
echo.

echo [2/3] Building release APK...
echo This may take a few minutes...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo ERROR: APK build failed
    pause
    exit /b 1
)
echo APK built successfully.
echo.

echo [3/3] Copying APK to project root...
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_APK%"
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy APK
    pause
    exit /b 1
)
echo.
echo ========================================
echo          APK Build Complete!
echo  Location: %OUTPUT_APK%
echo ========================================
echo.
pause
