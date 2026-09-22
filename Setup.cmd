@echo off
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Setup.ps1"
set taskExit=%errorlevel%
pause
exit /b %taskExit%
