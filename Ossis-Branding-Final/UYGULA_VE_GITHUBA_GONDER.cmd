@echo off
setlocal
title OSSIS Final Branding
cd /d C:\ossis-build\rustdesk

python Ossis-Branding-Final\apply_final_branding.py
if errorlevel 1 (
  echo.
  echo ISLEM DURDU. Yukaridaki HATA satirini paylasin.
  pause
  exit /b 1
)

git add -A
git commit -m "Apply final Ossis Windows branding and self-host config"
if errorlevel 1 (
  echo Commit olusturulamadi.
  pause
  exit /b 1
)

git push origin master
if errorlevel 1 (
  echo GitHub push basarisiz.
  pause
  exit /b 1
)

echo.
echo BASARILI: Branding ve sunucu ayarlari GitHub'a gonderildi.
echo Simdi GitHub Actions icinden Build Ossis Remote Control workflow'unu yeniden calistirin.
pause
