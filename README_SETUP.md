# EduLink Setup Instructions

## Quick Start (Normal CMD)

### Step 1: Start Backend Server
Open CMD and run:
```cmd
cd E:\EduLink-Complete
START_SERVER.bat
```

This will:
- Check PHP and Composer installation
- Install dependencies
- Run database migrations
- Start Laravel API on http://127.0.0.1:8000 and Reverb real-time chat on port 8080

**Keep this CMD window open** - the server must stay running.

### Step 2: Build APK
Open a NEW CMD window and run:
```cmd
cd E:\EduLink-Complete
BUILD_APK.bat
```

This will:
- Check Flutter installation
- Install dependencies
- Build release APK
- Copy APK to: `E:\EduLink-Complete\EduLink-App.apk`

### Step 3: Install on Phone
1. Transfer `E:\EduLink-Complete\EduLink-App.apk` to your phone
2. Install the APK
3. Make sure your phone is on the same WiFi network as your PC
4. Open the app

## Manual Setup (If Scripts Don't Work)

### Backend Setup
```cmd
cd E:\EduLink-Complete\backend
composer install
php artisan migrate --force
start /B php artisan reverb:start --host=0.0.0.0 --port=8080
php artisan serve
```

### APK Build
```cmd
cd E:\EduLink-Complete\flutter_app
flutter pub get
flutter build apk --release
copy build\app\outputs\flutter-apk\app-release.apk ..\EduLink-App.apk
```

## Troubleshooting

### App Still Crashes?
1. **Check backend is running**: Open browser to http://127.0.0.1:8000
2. **Check network**: Phone must be on same WiFi as PC
3. **Check API URL**: App connects to http://10.90.191.180:8000/api
4. **Enable USB debugging**: Connect phone to PC and run:
   ```cmd
   flutter devices
   flutter run
   ```
   This will show crash logs in real-time.

### Backend Not Starting?
1. Check PHP is installed: `php --version`
2. Check Composer is installed: `composer --version`
3. Check port 8000 is not in use: `netstat -ano | findstr :8000`

### APK Build Fails?
1. Check Flutter is installed: `flutter --version`
2. Check Android SDK is installed
3. Run `flutter doctor` to see issues

## Current Configuration

- **Backend URL**: http://10.90.191.180:8000/api
- **App ID**: com.edulink.app
- **Google Client ID**: 264019535722-fg4ic8fo6b15uj6na9s5ijtcrgais7t4.apps.googleusercontent.com
- **Database**: SQLite (migrations complete)

## Important Notes

- Backend server must stay running while using the app
- Phone and PC must be on same network
- First login will be slow (API connection)
- If app crashes, check backend logs in the server CMD window
