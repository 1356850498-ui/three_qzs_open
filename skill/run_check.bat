@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_check.ps1"
set "check_exit=%ERRORLEVEL%"
echo.
echo Open results\check_result.txt for details if the check ran.
pause
exit /b %check_exit%
