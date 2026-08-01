@echo off
REM Script to build Windows installer for Sanad
REM Batch file wrapper for build_windows_installer.ps1

setlocal enabledelayedexpansion

REM Check if PowerShell is available
where powershell >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: PowerShell not found
    pause
    exit /b 1
)

REM Get the directory where this script is located
set SCRIPT_DIR=%~dp0

REM Navigate to project root (release/windows/ -> project root)
cd /d "%SCRIPT_DIR%..\.."

REM Check if build_installer.ps1 exists
if not exist "release\windows\build_installer.ps1" (
    echo ERROR: build_installer.ps1 not found
    pause
    exit /b 1
)

REM Run PowerShell script
echo Running Windows installer build...
echo.

powershell -ExecutionPolicy Bypass -File "release\windows\build_installer.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo.
echo Build completed successfully!
pause
