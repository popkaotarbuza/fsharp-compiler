@echo off
setlocal

chcp 65001 >nul
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%run_tests.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

exit /b %EXIT_CODE%
