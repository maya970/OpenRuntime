@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"
set "OUT=%~dp0dist\OpenRuntime-offline.zip"
if not exist "%~dp0dist" mkdir "%~dp0dist"
echo Packing offline release (includes packages\) ...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "if (Test-Path '%OUT%') { Remove-Item '%OUT%' -Force };" ^
  "$files = Get-ChildItem -Force | Where-Object { $_.Name -notin @('.git','dist') };" ^
  "Compress-Archive -Path ($files.FullName) -DestinationPath '%OUT%' -CompressionLevel Optimal;" ^
  "Write-Host ('Created: %OUT%  size=' + [math]::Round((Get-Item '%OUT%').Length/1MB,1) + ' MB')"
echo.
pause
