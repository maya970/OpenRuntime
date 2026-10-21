param([string]$Path)
$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

. (Join-Path $Root 'src\Robust.ps1')
. (Join-Path $Root 'src\Runtimes.ps1')
. (Join-Path $Root 'src\Core.ps1')
. (Join-Path $Root 'src\Extra.ps1')
. (Join-Path $Root 'src\PeScan.ps1')
. (Join-Path $Root 'src\Win7Compat.ps1')
Set-OpenRuntimeRoot -Root $Root

if (-not $Path) {
    Write-Host '用法：把打不开 / 闪退的程序 exe 拖到 Fix-Win7App.bat 上。'
    exit 1
}

$r = Repair-OrCompatApp -Path $Path -Progress { param($m) Write-Host ('  ' + $m) }
Write-Host ''
if ($r.Ok) { Write-Host $r.Message -ForegroundColor Green }
else { Write-Host $r.Message -ForegroundColor Yellow }
if ($r.Ok) { exit 0 }
exit 1
