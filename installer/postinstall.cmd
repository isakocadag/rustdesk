@echo off
set "APP=%~dp0OssisRemoteControl.exe"
set "CONFIG===Qfi0TUPRWYSVlSFx2ZoRkUG5Gc012YHdGd2h3dDJlZrVFbYJ3VwBnNHdkYDB3NiojI5V2aiwiIiojIpBXYiwiIiojI5FGblJnIsISbvNmLtl2cpxWaiNXazN3bus2clRGcsVGaiojI0N3boJye"

taskkill /F /IM RustDesk.exe >nul 2>&1
taskkill /F /IM OssisRemoteControl.exe >nul 2>&1

sc.exe stop RustDesk >nul 2>&1
sc.exe delete RustDesk >nul 2>&1

"%APP%" --config "%CONFIG%"

sc.exe create RustDesk binPath= "\"%APP%\" --service" start= auto
sc.exe description RustDesk "Ossis Remote Control Service"
sc.exe start RustDesk

exit /b 0
