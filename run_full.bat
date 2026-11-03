@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build\scripts\run_all.ps1" %*
set "run_exit=%ERRORLEVEL%"
echo.
echo See build\reproduction_logs and build\reports for details.
pause
exit /b %run_exit%
