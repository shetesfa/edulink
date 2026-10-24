$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
Set-Location 'e:\EduLink-Complete\flutter_app'
Write-Host "Building release APK..."
flutter build apk --release --no-shrink
if ($LASTEXITCODE -eq 0) {
    Copy-Item 'build\app\outputs\flutter-apk\app-release.apk' 'e:\EduLink-Complete\EduLink-App.apk' -Force
    Write-Host "SUCCESS: EduLink-App.apk updated at root!"
} else {
    Write-Host "ERROR: APK build failed with code $LASTEXITCODE"
}
