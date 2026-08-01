@echo off
setlocal
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "release\windows\release.ps1"
exit /b %ERRORLEVEL%
