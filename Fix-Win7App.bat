@echo off
setlocal EnableExtensions
title OpenRuntime - Fix App
cd /d "%~dp0"

set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PSEXE%" set "PSEXE=%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"

if "%~1"=="" goto :Usage

net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 goto :DoElevate

"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Run-FixApp.ps1" -Path "%~1"
echo.
pause
exit /b 0

:DoElevate
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Elevate.ps1" -Target "%~f0" -Arguments "\"%~1\""
exit /b 0

:Usage
echo Drag one program (exe) onto this bat. It will fix it automatically.
echo Then double-click that program. Nothing else to click.
pause
exit /b 1
