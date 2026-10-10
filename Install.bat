@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
title OpenRuntime
cd /d "%~dp0"

REM ---- Find powershell.exe ----
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PSEXE%" set "PSEXE=%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PSEXE%" (
    echo [ERROR] powershell.exe not found
    pause
    exit /b 1
)

REM ---- Elevate without nested ) that break bat parsing ----
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 goto :DoElevate
goto :RunMain

:DoElevate
echo Requesting administrator...
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Elevate.ps1" -Target "%~f0"
if %ERRORLEVEL% NEQ 0 goto :DoElevateMshta
exit /b 0

:DoElevateMshta
REM Keep outside if (...) blocks: the ) inside mshta args would cut the block short
mshta "javascript:Close(new ActiveXObject('Shell.Application').ShellExecute('%~f0','','','runas',1))"
exit /b 0

:RunMain
echo.
echo OpenRuntime
echo -----------------------------------------
echo.

REM TLS bootstrap via -File only (no -Command with ^& or $var%% )
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Run-TlsBootstrap.ps1" >nul 2>&1

echo [1/2] PowerShell / WMF check...
REM Do not redirect PS output to nul: Win7 may fail with "cannot write to the specified device"
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Ensure-PowerShell51.ps1"
set "BOOT=%ERRORLEVEL%"
if "%BOOT%"=="2" echo [Tip] WMF installed, reboot later recommended.

echo [2/2] Starting UI...
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0OpenRuntime.ps1" %*
set "ERR=%ERRORLEVEL%"

if "%ERR%"=="0" goto :EndOk
if "%ERR%"=="2" goto :EndOk

echo Retry launch...
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Run-Main.ps1"
set "ERR=%ERRORLEVEL%"

if not "%ERR%"=="0" (
    echo Exit code: %ERR%
    echo Try Install-Console.bat if UI failed.
    pause
)

:EndOk
endlocal & exit /b %ERR%
