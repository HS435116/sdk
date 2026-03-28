@echo off
echo Pushing APK to connected Android device...
adb install -r build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
if %errorlevel% equ 0 (
    echo APK pushed successfully.
) else (
    echo Push failed. Make sure device is connected and USB debugging is enabled.
)
