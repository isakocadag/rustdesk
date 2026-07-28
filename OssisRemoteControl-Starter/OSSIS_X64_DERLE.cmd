@echo off
setlocal EnableExtensions
title Ossis Remote Control - X64 Builder
set "ROOT=C:\ossis-build\rustdesk"
set "VCPKG=C:\ossis-build\vcpkg"
set "GITBASH=C:\Program Files\Git\bin\bash.exe"
set "VSDEV=C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"

if not exist "%ROOT%\Cargo.toml" goto fail
if not exist "%GITBASH%" goto fail
if not exist "%VSDEV%" goto fail

call "%VSDEV%" -arch=x64 -host_arch=x64
if errorlevel 1 goto fail

set "PROCESSOR_ARCHITECTURE=AMD64"
set "PROCESSOR_ARCHITEW6432=AMD64"
set "VCPKG_ROOT=%VCPKG%"
set "VCPKG_DEFAULT_TRIPLET=x64-windows-static"
set "VCPKG_DEFAULT_HOST_TRIPLET=x64-windows-static"
set "VCPKGRS_TRIPLET=x64-windows-static"
set "CARGO_BUILD_TARGET=x86_64-pc-windows-msvc"
set "LIBCLANG_PATH=C:\Program Files\LLVM\bin"
set "CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\link.exe"
set "CC_x86_64_pc_windows_msvc=cl.exe"
set "CXX_x86_64_pc_windows_msvc=cl.exe"

rustup target add x86_64-pc-windows-msvc
if errorlevel 1 goto fail

"%VCPKG%\vcpkg.exe" install opus:x64-windows-static libsodium:x64-windows-static libvpx:x64-windows-static libyuv:x64-windows-static aom:x64-windows-static
if errorlevel 1 goto fail

if exist "%ROOT%\target" rmdir /s /q "%ROOT%\target"
if exist "%ROOT%\flutter\build\windows" rmdir /s /q "%ROOT%\flutter\build\windows"

cd /d "%ROOT%"
"%GITBASH%" -lc "export PROCESSOR_ARCHITECTURE=AMD64; export PROCESSOR_ARCHITEW6432=AMD64; export VCPKG_ROOT=/c/ossis-build/vcpkg; export VCPKG_DEFAULT_TRIPLET=x64-windows-static; export VCPKG_DEFAULT_HOST_TRIPLET=x64-windows-static; export VCPKGRS_TRIPLET=x64-windows-static; export CARGO_BUILD_TARGET=x86_64-pc-windows-msvc; export LIBCLANG_PATH='/c/Program Files/LLVM/bin'; export CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER='/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/link.exe'; cd /c/ossis-build/rustdesk; python OssisRemoteControl-Starter/scripts/apply_branding.py; python build.py --flutter"
if errorlevel 1 goto fail

if not exist "%ROOT%\OssisRemoteControl-Starter\output" mkdir "%ROOT%\OssisRemoteControl-Starter\output"

set "FOUND="
for %%F in (
  "%ROOT%\flutter\build\windows\x64\runner\Release\rustdesk.exe"
  "%ROOT%\flutter\build\windows\runner\Release\rustdesk.exe"
  "%ROOT%\target\x86_64-pc-windows-msvc\release\rustdesk.exe"
  "%ROOT%\target\release\rustdesk.exe"
) do if exist "%%~F" set "FOUND=%%~F"

if not defined FOUND for /r "%ROOT%\flutter\build\windows" %%F in (rustdesk.exe) do if not defined FOUND set "FOUND=%%~fF"
if not defined FOUND goto fail

copy /y "%FOUND%" "%ROOT%\OssisRemoteControl-Starter\output\OssisRemoteControl.exe" >nul
echo.
echo BASARILI:
echo %ROOT%\OssisRemoteControl-Starter\output\OssisRemoteControl.exe
pause
exit /b 0

:fail
echo.
echo DERLEME BASARISIZ.
echo Ekrandaki ilk kirmizi hata satirini paylasin.
pause
exit /b 1
