@echo off
setlocal
cd /d "%~dp0\..\.."
"C:\Program Files\Git\bin\bash.exe" "OssisRemoteControl-Starter/scripts/prepare_dependencies.sh"
if errorlevel 1 pause & exit /b 1
"C:\Program Files\Git\bin\bash.exe" "OssisRemoteControl-Starter/scripts/build_ossis.sh"
pause
