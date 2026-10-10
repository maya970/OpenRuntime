@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
title OpenRuntime Electron Polyfill Launcher

set "POLY=%~dp0promise-withresolvers-polyfill.js"
if not exist "%POLY%" (
    echo [ERROR] missing promise-withresolvers-polyfill.js
    pause
    exit /b 1
)

set "TARGET="
set "WORKDIR=%~dp0"

if not "%~1"=="" (
    set "TARGET=%~1"
    set "WORKDIR=%~dp1"
    goto :Go
)

for %%E in (
    "Clash Party.exe"
    "clash-party.exe"
    "Mihomo Party.exe"
    "mihomo-party.exe"
    "Clash Verge.exe"
    "clash-verge.exe"
    "clash-win7.exe"
    "Clash.exe"
) do if exist "%~dp0%%~E" (
    set "TARGET=%~dp0%%~E"
    set "WORKDIR=%~dp0"
    goto :Go
)

echo Drag the Clash exe onto this bat, or copy both files into the Clash folder.
pause
exit /b 1

:Go
if not exist "%TARGET%" (
    echo [ERROR] not found: %TARGET%
    pause
    exit /b 1
)

echo Polyfill: %POLY%
echo Launch:   %TARGET%
echo.

REM paths with spaces: use --require=...
set "NODE_OPTIONS=--require=%POLY%"
set "ELECTRON_NODE_OPTIONS=--require=%POLY%"

cd /d "%WORKDIR%"
"%TARGET%"
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
    echo Exit code: %ERR%
    pause
)
endlocal & exit /b %ERR%
