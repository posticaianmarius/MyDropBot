@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Send-ToPhone.ps1" -Pair
set "result=%errorlevel%"
echo(
pause
exit /b %result%
