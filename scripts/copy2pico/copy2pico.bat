@echo off
chcp 65001 >nul
echo ========================================
echo   Homeocto-App -^> Picoclaw-FUI Sync Tool
echo ========================================
echo.

cd /d "%~dp0"

echo Running sync script...
echo.

powershell -ExecutionPolicy Bypass -File ".\copy2pico.ps1"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Press any key to exit...
    pause >nul
) else (
    echo.
    echo Script failed with error code: %ERRORLEVEL%
    pause >nul
    exit /b %ERRORLEVEL%
)
