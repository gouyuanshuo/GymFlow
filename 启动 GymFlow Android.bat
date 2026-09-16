@echo off
chcp 65001 >nul
setlocal
title GymFlow Android

set "SDK=%ANDROID_HOME%"
if not defined SDK set "SDK=D:\Android\android-sdk"
set "ANDROID_AVD_HOME=D:\Android\avd"
set "ADB=%SDK%\platform-tools\adb.exe"
set "EMULATOR=%SDK%\emulator\emulator.exe"
set "AVD_NAME=GymFlow_Visual_API36"
set "PACKAGE=com.gouyuanshuo.gymflow"
set "ACTIVITY=com.gouyuanshuo.gymflow/.MainActivity"
set "APK=%~dp0dist\GymFlow-Android-v1.0.0.apk"

if not exist "%ADB%" goto missing_sdk
if not exist "%EMULATOR%" goto missing_sdk

echo [GymFlow] 正在检查 Android 模拟器...
"%ADB%" start-server >nul 2>&1
"%ADB%" -e get-state >nul 2>&1
if not errorlevel 1 goto wait_boot

echo [GymFlow] 正在启动模拟器，请稍候...
start "" "%EMULATOR%" -avd "%AVD_NAME%"

set /a WAIT_COUNT=0
:wait_device
"%ADB%" -e get-state >nul 2>&1
if not errorlevel 1 goto wait_boot
ping 127.0.0.1 -n 3 >nul
set /a WAIT_COUNT+=1
if %WAIT_COUNT% GEQ 60 goto boot_timeout
goto wait_device

:wait_boot
echo [GymFlow] 正在等待 Android 系统启动完成...
set /a WAIT_COUNT=0
:check_boot
set "BOOT_DONE="
for /f "delims=" %%G in ('"%ADB%" -e shell getprop sys.boot_completed 2^>nul') do set "BOOT_DONE=%%G"
if "%BOOT_DONE%"=="1" goto device_ready
ping 127.0.0.1 -n 3 >nul
set /a WAIT_COUNT+=1
if %WAIT_COUNT% GEQ 60 goto boot_timeout
goto check_boot

:device_ready
"%ADB%" -e shell pm path %PACKAGE% 2>nul | findstr /B /C:"package:" >nul
if not errorlevel 1 goto launch_app

if not exist "%APK%" goto missing_apk
echo [GymFlow] 首次使用，正在安装 APK...
"%ADB%" -e install "%APK%"
if errorlevel 1 goto install_failed

:launch_app
echo [GymFlow] 正在打开 GymFlow...
"%ADB%" -e shell am start -W -n %ACTIVITY%
if errorlevel 1 goto launch_failed
echo.
echo [GymFlow] 启动成功，可以关闭这个窗口了。
ping 127.0.0.1 -n 4 >nul
exit /b 0

:missing_sdk
echo.
echo [错误] 找不到 Android SDK：%SDK%
echo 请确认 Android 工具位于 D:\Android\android-sdk。
goto failed

:missing_apk
echo.
echo [错误] 模拟器中尚未安装 GymFlow，并且找不到：
echo %APK%
goto failed

:install_failed
echo.
echo [错误] APK 安装失败。
goto failed

:launch_failed
echo.
echo [错误] GymFlow 启动失败。
goto failed

:boot_timeout
echo.
echo [错误] 模拟器在 120 秒内没有启动完成。
goto failed

:failed
echo.
pause
exit /b 1
