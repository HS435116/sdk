@echo off
echo Building APK for Android 4.4 and Mediapad 10 Link+...
flutter build apk --release
if %errorlevel% equ 0 (
    echo APK built successfully.
    echo APK location: build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
) else (
    echo Build failed.
    exit /b 1
)
