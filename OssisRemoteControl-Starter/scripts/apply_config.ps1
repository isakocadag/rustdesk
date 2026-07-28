$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Candidates = @(
    (Join-Path $PSScriptRoot "..\output\OssisRemoteControl.exe"),
    (Join-Path $Root "flutter\build\windows\x64\runner\Release\rustdesk.exe"),
    (Join-Path $Root "flutter\build\windows\runner\Release\rustdesk.exe")
)
$Exe = $Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Exe) { throw "Derlenmiş EXE bulunamadı." }

$Config = "==Qfi0TUPRWYSVlSFx2ZoRkUG5Gc012YHdGd2h3dDJlZrVFbYJ3VwBnNHdkYDB3NiojI5V2aiwiIiojIpBXYiwiIiojI5FGblJnIsISbvNmLtl2cpxWaiNXazN3bus2clRGcsVGaiojI0N3boJye"
Start-Process -FilePath $Exe -ArgumentList @("--config", $Config) -Wait
Write-Host "helpdesk.ossisbilisim.com yapılandırması uygulandı." -ForegroundColor Green
Start-Process -FilePath $Exe
