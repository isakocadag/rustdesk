@echo off
set "APP=%~dp0OssisRemoteSRV.exe"
set "CONFIG===Qfi0TUPRWYSVlSFx2ZoRkUG5Gc012YHdGd2h3dDJlZrVFbYJ3VwBnNHdkYDB3NiojI5V2aiwiIiojIpBXYiwiIiojI5FGblJnIsISbvNmLtl2cpxWaiNXazN3bus2clRGcsVGaiojI0N3boJye"

if /I "%~1"=="config" (
  "%APP%" --config "%CONFIG%"
  exit /b %errorlevel%
)

exit /b 0
