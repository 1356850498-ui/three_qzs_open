@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build\scripts\prepare_project.ps1" %*
set "run_exit=%ERRORLEVEL%"
echo.
echo If successful, open board\project_main\cascade_qzs.xpr in Vivado.
pause
exit /b %run_exit%
