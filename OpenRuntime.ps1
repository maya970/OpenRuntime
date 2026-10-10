<#
.SYNOPSIS
    OpenRuntime — free Windows runtime redistributable installer (PowerShell 2.0+).

.DESCRIPTION
    Detects and installs Visual C++ Redistributables, .NET Framework 4.8, and DirectX.
    Downloads via bundled curl (LibreSSL TLS 1.2) so Win7 without system TLS still works.
    Also enables Schannel TLS 1.2 registry keys when running as admin.

.PARAMETER Console
    Run in console mode (no GUI).

.PARAMETER Auto
    In console mode, install all missing packages without prompting.

.PARAMETER Force
    Reinstall even if detection believes the package is present.

.PARAMETER List
    Only list detection results and exit.

.PARAMETER NoPause
    Do not wait for a key at the end.
#>
param(
    [switch]$Console,
    [switch]$Auto,
    [switch]$Force,
    [switch]$List,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $Root 'src\TlsBootstrap.ps1')
. (Join-Path $Root 'src\Robust.ps1')
. (Join-Path $Root 'src\Runtimes.ps1')
. (Join-Path $Root 'src\Core.ps1')
. (Join-Path $Root 'src\Extra.ps1')
. (Join-Path $Root 'src\PeScan.ps1')
. (Join-Path $Root 'src\Win7Compat.ps1')

Set-OpenRuntimeRoot -Root $Root
Initialize-OpenRuntimeEnvironment

function Write-Banner {
    Write-Host ''
    Write-Host '  OpenRuntime  -  open-source runtime installer' -ForegroundColor Cyan
    Write-Host '  https://github.com/maya970' -ForegroundColor DarkGray
    Write-Host '  Free / no adware / Microsoft official downloads' -ForegroundColor DarkGray
    Write-Host ''
    $info = Get-OpenRuntimeSystemInfo
    $cap = ''
    if ($info.Caption) { $cap = $info.Caption.Trim() }
    Write-Host ("  OS: {0} ({1})" -f $cap, $info.Arch)
    Write-Host ("  PowerShell: {0}  |  Admin: {1}  |  curl: {2}  |  Offline: {3}" -f $info.PSVersion, $info.IsAdmin, $info.HasCurl, $info.OfflineReady)
    Write-Host ''
}

function Show-StatusTable {
    $rows = Get-OpenRuntimeStatusList
    $rows | Select-Object Status, Name, Arch, Category, Note | Format-Table -AutoSize
    $missing = 0
    foreach ($r in $rows) {
        if (-not $r.Installed) { $missing++ }
    }
    Write-Host ("  Total {0}, missing {1}." -f @($rows).Count, $missing) -ForegroundColor Yellow
    return $rows
}

function Wait-KeyIfNeeded {
    if ($NoPause) { return }
    if ($Host.Name -ne 'ConsoleHost') { return }
    Write-Host 'Press any key to exit...' -ForegroundColor DarkGray
    try {
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        Read-Host 'Enter'
    }
}

if ($List) {
    Write-Banner
    Show-StatusTable | Out-Null
    Wait-KeyIfNeeded
    exit 0
}

if (-not $Console) {
    . (Join-Path $Root 'src\Gui.ps1')
    try {
        Show-OpenRuntimeGui
        exit 0
    }
    catch {
        Write-Warning ("GUI failed, fallback to console: " + $_.Exception.Message)
        $Console = $true
    }
}

Write-Banner
$rows = Show-StatusTable

if (-not (Test-IsAdministrator)) {
    Write-Host ''
    Write-Host '  [!] Not admin. Right-click Install.bat -> Run as administrator.' -ForegroundColor Red
    Write-Host ''
    Wait-KeyIfNeeded
    exit 1
}

$targets = @()
if ($Force) {
    $targets = @($rows)
}
else {
    foreach ($r in $rows) {
        if (-not $r.Installed) { $targets += $r }
    }
}

if (@($targets).Count -eq 0) {
    Write-Host '  All runtimes already installed.' -ForegroundColor Green
    Wait-KeyIfNeeded
    exit 0
}

if (-not $Auto) {
    Write-Host ''
    Write-Host ("  Install {0} missing package(s)? [Y/N]" -f @($targets).Count) -ForegroundColor Cyan
    $ans = Read-Host '  '
    if ($ans -notmatch '^[Yy]') {
        Write-Host '  Cancelled.'
        exit 0
    }
}

Write-Host ''
$results = @()
$i = 0
foreach ($t in $targets) {
    $i++
    Write-Host ("  [{0}/{1}] {2}" -f $i, @($targets).Count, $t.Name) -ForegroundColor White
    $r = Install-OpenRuntimeItem -Item $t.Item -Force:$Force -Progress {
        param($msg)
        Write-Host ("         {0}" -f $msg) -ForegroundColor DarkGray
    }
    $results += $r
    $color = 'Red'
    if ($r.Success) { $color = 'Green' }
    Write-Host ("         -> {0}" -f $r.Message) -ForegroundColor $color
}

Write-Host ''
$ok = 0
$fail = 0
foreach ($r in $results) {
    if ($r.Success) { $ok++ } else { $fail++ }
}
$summaryColor = 'Green'
if ($fail -gt 0) { $summaryColor = 'Yellow' }
Write-Host ("  Done: ok/skip {0}, fail {1}" -f $ok, $fail) -ForegroundColor $summaryColor
Write-Host ''

Wait-KeyIfNeeded

if ($fail -gt 0) { exit 2 }
exit 0
