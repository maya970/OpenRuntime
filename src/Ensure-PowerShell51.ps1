# OpenRuntime — ensure PS 5.1 via offline packages (multi-method, PS2-safe)
# Exit: 0=ok/continue, 2=need reboot, 1=hard fail (still allow continue from bat)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# Load robust helpers if present
$robust = Join-Path $Root 'src\Robust.ps1'
if (Test-Path -LiteralPath $robust) {
    . $robust
}

function Get-Wmf51State {
    if (Get-Command Get-OrWmf51State -ErrorAction SilentlyContinue) {
        return (Get-OrWmf51State)
    }
    try {
        $v = $PSVersionTable.PSVersion
        if ($v.Major -gt 5 -or ($v.Major -eq 5 -and $v.Minor -ge 1)) { return 'Active' }
    }
    catch { }
    return 'NotInstalled'
}

function Find-Pkg {
    param([string]$Name, [string]$Pattern)
    $dirs = @(
        (Join-Path $Root 'packages'),
        $Root,
        (Split-Path -Parent $Root),
        (Join-Path (Split-Path -Parent $Root) 'packages')
    )
    foreach ($d in $dirs) {
        if (-not (Test-Path -LiteralPath $d) -and -not (Test-Path -Path $d)) { continue }
        $exact = Join-Path $d $Name
        if (Test-Path -LiteralPath $exact) { return $exact }
        if (Test-Path -Path $exact) { return $exact }
        if ($Pattern) {
            if (Get-Command Get-OrChildFiles -ErrorAction SilentlyContinue) {
                $hit = Get-OrChildFiles -Path $d -Filter $Pattern | Sort-Object Length -Descending | Select-Object -First 1
                if ($hit) { return $hit.FullName }
            }
            else {
                $hit = Get-ChildItem -Path $d -Filter $Pattern -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.PSIsContainer } |
                    Sort-Object Length -Descending |
                    Select-Object -First 1
                if ($hit) { return $hit.FullName }
            }
        }
    }
    return $null
}

function Start-Quiet {
    param([string]$Exe, [string]$Args)
    if (-not $Args) { throw 'Start-Quiet 需要参数' }
    # ProcessStartInfo：整串 Arguments，避免 Start-Process -ArgumentList 拆坏引号
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Exe
        $psi.Arguments = $Args
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        [void]$p.Start()
        $p.WaitForExit()
        return $p.ExitCode
    }
    catch { }
    try {
        $cmdLine = '"' + $Exe + '" ' + $Args
        $p2 = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $cmdLine) -Wait -PassThru -WindowStyle Hidden
        return $p2.ExitCode
    }
    catch { }
    if (Get-Command Start-OrProcess -ErrorAction SilentlyContinue) {
        return (Start-OrProcess -FilePath $Exe -Arguments $Args -ProgressText '安装中' -TimeoutSec 7200)
    }
    throw 'Start-Quiet 全部失败'
}

function Write-Safe {
    param([string]$Text, [string]$Color = $null)
    try {
        if ($Color) { Write-Host $Text -ForegroundColor $Color }
        else { Write-Host $Text }
    }
    catch {
        try { [Console]::Out.WriteLine($Text) } catch { }
    }
}

Write-Safe ''
Write-Safe '  [PowerShell] 检查版本（老机器兼容模式）...' 'Cyan'
try { Write-Safe ("  当前: {0}" -f $PSVersionTable.PSVersion) } catch { Write-Safe '  当前: 未知' }

$os = [Environment]::OSVersion.Version
if ($os.Major -ge 10) {
    Write-Safe '  Win10/11 跳过 WMF。' 'Yellow'
    exit 0
}

$state = Get-Wmf51State
if ($state -eq 'Active') {
    Write-Safe '  已是 PowerShell 5.1+。' 'Green'
    exit 0
}
if ($state -eq 'PendingReboot') {
    Write-Safe '  WMF 5.1 已在待安装队列，但还没生效：请重启电脑。' 'Yellow'
    exit 2
}

Write-Safe '  尝试离线升级到 PowerShell 5.1（失败也不中断主程序）...' 'Yellow'

# .NET prerequisite — try multiple packages
$ndp = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
$needNet = $true
if (Test-Path -LiteralPath $ndp) {
    try {
        $rel = (Get-ItemProperty -Path $ndp).Release
        if ($rel -ge 379893) { $needNet = $false }
    }
    catch { }
}

if ($needNet) {
    $net = Find-Pkg -Name 'ndp48-x86-x64-AllOS-ENU.exe' -Pattern 'ndp48*.exe'
    if (-not $net) { $net = Find-Pkg -Name 'ndp48-web.exe' -Pattern '*NDP48*.exe' }
    if ($net) {
        Write-Safe ("  安装 .NET: {0}" -f $net)
        foreach ($a in @('/q /norestart', '/quiet /norestart', '/q', '/passive /norestart')) {
            try {
                $c = Start-Quiet -Exe $net -Args $a
                Write-Safe ("  .NET 参数 [{0}] 退出码 {1}" -f $a, $c)
                if ($c -eq 0 -or $c -eq 3010 -or $c -eq 1638) { break }
            }
            catch { }
        }
    }
    else {
        Write-Safe '  未找到 .NET 离线包，继续尝试 WMF…' 'Yellow'
    }
}

$is64 = $false
if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') { $is64 = $true }
if ($env:PROCESSOR_ARCHITEW6432 -eq 'AMD64') { $is64 = $true }

$msuList = @()
if ($os.Major -eq 6 -and $os.Minor -eq 1) {
    if ($is64) {
        $msuList += Find-Pkg -Name 'Win7AndW2K8R2-KB3191566-x64.msu' -Pattern '*KB3191566*x64*.msu'
        $msuList += Find-Pkg -Name 'Win7AndW2K8R2-KB3191566-x64.zip' -Pattern '*KB3191566*x64*.zip'
    }
    else {
        $msuList += Find-Pkg -Name 'Win7-KB3191566-x86.msu' -Pattern '*KB3191566*x86*.msu'
        $msuList += Find-Pkg -Name 'Win7-KB3191566-x86.zip' -Pattern '*KB3191566*x86*.zip'
    }
}
elseif ($os.Major -eq 6 -and $os.Minor -ge 3) {
    $msuList += Find-Pkg -Name 'Win8.1AndW2K12R2-KB3191564-x64.msu' -Pattern '*KB3191564*.msu'
}

$msuList = @($msuList | Where-Object { $_ } | Select-Object -Unique)
if ($msuList.Count -eq 0) {
    Write-Safe '  无 WMF 离线包，使用 PS2 兼容模式继续。' 'Yellow'
    exit 0
}

foreach ($pkg in $msuList) {
    Write-Safe ("  尝试: {0}" -f $pkg)
    $targetMsu = $pkg
    if ($pkg -match '\.zip$') {
        $extract = Join-Path $env:TEMP 'OpenRuntime_WMF'
        try {
            if (Get-Command Expand-OrArchive -ErrorAction SilentlyContinue) {
                if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue }
                New-Item -ItemType Directory -Path $extract -Force | Out-Null
                Expand-OrArchive -ZipPath $pkg -Destination $extract | Out-Null
                $found = Get-OrChildFiles -Path $extract -Filter '*.msu' -Recurse | Select-Object -First 1
                if ($found) { $targetMsu = $found.FullName }
            }
        }
        catch {
            Write-Safe ("  ZIP 解压失败: {0}" -f $_.Exception.Message)
            continue
        }
    }

    if (-not $targetMsu -or ($targetMsu -notmatch '\.msu$')) {
        Write-Safe '  未解析到 .msu，跳过。' 'Yellow'
        continue
    }

    if (-not (Get-Command Install-OrMsu -ErrorAction SilentlyContinue)) {
        Write-Safe '  缺少 src\Robust.ps1，无法安装 WMF。' 'Red'
        exit 1
    }

    try {
        Write-Safe '  安装 MSU（Update 禁用时按顺序 DISM 安装全部 CAB）…'
        $code = Install-OrMsu -MsuPath $targetMsu -Progress { param($m) Write-Safe ('    ' + $m) }
        Write-Safe ("  退出码: {0}" -f $code)
    }
    catch {
        Write-Safe ("  失败: {0}" -f $_.Exception.Message)
    }

    # 退出码不可信，按系统实际状态判断
    $state = Get-Wmf51State
    if ($state -eq 'Active') {
        Write-Safe '  PowerShell 5.1 已生效。' 'Green'
        exit 0
    }
    if ($state -eq 'PendingReboot') {
        Write-Safe '  KB3191566 已进入安装队列，重启电脑后 PowerShell 才会变为 5.1。' 'Yellow'
        exit 2
    }
    Write-Safe '  本包没有真正装上（KB3191566 不在已安装/待安装状态）。' 'Red'
}

Write-Safe '  PowerShell 5.1 未安装成功，本次继续用当前 PowerShell。详见 %TEMP%\OpenRuntime_DISM_*.log' 'Red'
exit 1
