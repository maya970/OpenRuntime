@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
title OpenRuntime Console
cd /d "%~dp0"

set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PSEXE%" set "PSEXE=%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PSEXE%" (
    echo [ERROR] powershell.exe not found
    pause
    exit /b 1
)

net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 goto :DoElevate
goto :RunMain

:DoElevate
echo Requesting administrator...
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Elevate.ps1" -Target "%~f0"
if %ERRORLEVEL% NEQ 0 goto :DoElevateMshta
exit /b 0

:DoElevateMshta
mshta "javascript:Close(new ActiveXObject('Shell.Application').ShellExecute('%~f0','','','runas',1))"
exit /b 0

:RunMain
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Run-TlsBootstrap.ps1" >nul 2>&1
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Ensure-PowerShell51.ps1"
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0OpenRuntime.ps1" -Console -Auto %*
set "ERR=%ERRORLEVEL%"
echo.
pause
endlocal & exit /b %ERR%
