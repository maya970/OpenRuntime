# OpenRuntime — multi-method fallbacks for ancient / broken Windows
# PowerShell 2.0+ safe. Prefer calling through these helpers everywhere.

$script:OrLastMethod = ''

function Get-OrLastMethod { return $script:OrLastMethod }

function Write-OrTryLog {
    param([string]$Message, [scriptblock]$Progress = $null)
    $script:OrLastMethod = $Message
    if ($Progress) {
        try { & $Progress $Message } catch { }
    }
}

function Test-OrPath {
    param([string]$Path)
    if (-not $Path) { return $false }
    try {
        if (Test-Path -LiteralPath $Path) { return $true }
    }
    catch { }
    try {
        if (Test-Path -Path $Path) { return $true }
    }
    catch { }
    return $false
}

function Get-OrItemLength {
    param([string]$Path)
    try { return (Get-Item -LiteralPath $Path -ErrorAction Stop).Length } catch { }
    try { return (Get-Item -Path $Path -ErrorAction Stop).Length } catch { }
    return 0
}

function Test-OrFileOk {
    param([string]$Path, [long]$MinSize = 1024)
    if (-not (Test-OrPath $Path)) { return $false }
    return ((Get-OrItemLength $Path) -ge $MinSize)
}

function Get-OrChildFiles {
    param(
        [string]$Path,
        [string]$Filter = $null,
        [switch]$Recurse
    )
    $list = @()
    if (-not (Test-OrPath $Path)) { return $list }

    $cmds = @()
    if ($Filter -and $Recurse) {
        $cmds += { Get-ChildItem -LiteralPath $Path -Filter $Filter -Recurse -ErrorAction SilentlyContinue }
        $cmds += { Get-ChildItem -Path $Path -Filter $Filter -Recurse -ErrorAction SilentlyContinue }
        $cmds += { Get-ChildItem -Path (Join-Path $Path '*') -Filter $Filter -Recurse -ErrorAction SilentlyContinue }
    }
    elseif ($Filter) {
        $cmds += { Get-ChildItem -LiteralPath $Path -Filter $Filter -ErrorAction SilentlyContinue }
        $cmds += { Get-ChildItem -Path $Path -Filter $Filter -ErrorAction SilentlyContinue }
        $cmds += { cmd /c "dir /b `"$Path\$Filter`"" 2>$null }
    }
    elseif ($Recurse) {
        $cmds += { Get-ChildItem -LiteralPath $Path -Recurse -ErrorAction SilentlyContinue }
        $cmds += { Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue }
    }
    else {
        $cmds += { Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue }
        $cmds += { Get-ChildItem -Path $Path -ErrorAction SilentlyContinue }
        $cmds += { cmd /c "dir /b `"$Path`"" 2>$null }
    }

    foreach ($c in $cmds) {
        try {
            $raw = & $c
            if (-not $raw) { continue }
            foreach ($r in @($raw)) {
                if ($null -eq $r) { continue }
                if ($r -is [System.IO.FileSystemInfo]) {
                    if (-not $r.PSIsContainer) { $list += $r }
                }
                else {
                    # dir /b returns strings
                    $name = [string]$r
                    if (-not $name) { continue }
                    $full = $name
                    if (-not (Test-OrPath $full)) {
                        $full = Join-Path $Path $name
                    }
                    if (Test-OrPath $full) {
                        try {
                            $it = Get-Item -LiteralPath $full -ErrorAction SilentlyContinue
                            if ($it -and (-not $it.PSIsContainer)) { $list += $it }
                        }
                        catch { }
                    }
                }
            }
            if ($list.Count -gt 0) { break }
        }
        catch { }
    }
    return $list
}

function New-OrDirectory {
    param([string]$Path)
    if (Test-OrPath $Path) { return $true }
    try { New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null; return $true } catch { }
    try { cmd /c "mkdir `"$Path`"" | Out-Null; return (Test-OrPath $Path) } catch { }
    return $false
}

function Expand-OrArchive {
    param(
        [string]$ZipPath,
        [string]$Destination,
        [scriptblock]$Progress = $null
    )
    if (-not (Test-OrFileOk $ZipPath)) { throw ("压缩包不存在: " + $ZipPath) }
    [void](New-OrDirectory $Destination)

    $errors = @()

    # 1) .NET ZipFile
    try {
        Write-OrTryLog '解压方法1: System.IO.Compression.ZipFile' $Progress
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $Destination)
        if (@(Get-OrChildFiles -Path $Destination -Recurse).Count -gt 0) { return 'ZipFile' }
    }
    catch { $errors += $_.Exception.Message }

    # 2) Shell.Application (Explorer)
    try {
        Write-OrTryLog '解压方法2: Shell.Application' $Progress
        $shell = New-Object -ComObject Shell.Application
        $zipNs = $shell.NameSpace((Get-Item -LiteralPath $ZipPath).FullName)
        $destNs = $shell.NameSpace((Get-Item -LiteralPath $Destination).FullName)
        $destNs.CopyHere($zipNs.Items(), 20)
        $deadline = (Get-Date).AddMinutes(5)
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 1
            try { [System.Windows.Forms.Application]::DoEvents() } catch { }
            if (@(Get-OrChildFiles -Path $Destination -Recurse).Count -gt 0) { return 'Shell.Application' }
        }
    }
    catch { $errors += $_.Exception.Message }

    # 3) tar (Win10+)
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-OrPath $tar) {
        try {
            Write-OrTryLog '解压方法3: tar.exe' $Progress
            $p = Start-Process -FilePath $tar -ArgumentList @('-xf', $ZipPath, '-C', $Destination) -Wait -PassThru -WindowStyle Hidden
            if (@(Get-OrChildFiles -Path $Destination -Recurse).Count -gt 0) { return 'tar' }
        }
        catch { $errors += $_.Exception.Message }
    }

    # 4) PowerShell Expand-Archive (PS5+)
    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
        try {
            Write-OrTryLog '解压方法4: Expand-Archive' $Progress
            Expand-Archive -Path $ZipPath -DestinationPath $Destination -Force
            if (@(Get-OrChildFiles -Path $Destination -Recurse).Count -gt 0) { return 'Expand-Archive' }
        }
        catch { $errors += $_.Exception.Message }
    }

    throw ("解压失败，已尝试多种方法。最后错误: " + ($errors -join ' | '))
}

function Start-OrProcess {
    param(
        [string]$FilePath,
        [string]$Arguments = '',
        [scriptblock]$Progress = $null,
        [string]$ProgressText = '安装中…',
        [int]$TimeoutSec = 3600,
        [string]$WorkDir = $null,
        [switch]$ShowWindow
    )
    if (-not (Test-OrPath $FilePath)) {
        throw ("找不到可执行文件: " + $FilePath)
    }

    # wusa 空参会弹出帮助窗口，直接拒绝
    $baseName = [System.IO.Path]::GetFileName($FilePath)
    if ($baseName -ieq 'wusa.exe') {
        if (-not $Arguments -or ($Arguments -notmatch '\.msu')) {
            throw '拒绝空参启动 wusa（会弹出帮助窗口）'
        }
    }

    # ProcessStartInfo.Arguments 按命令行解析；优先于 Start-Process -ArgumentList（易拆坏带引号参数）
    $methods = @('ProcessStartInfo_NoShell', 'ProcessStartInfo_Shell', 'cmd_start', 'Start-Process')
    $lastErr = $null

    foreach ($method in $methods) {
        $p = $null
        try {
            Write-OrTryLog ("启动方法: {0} — {1}" -f $method, $ProgressText) $Progress

            if ($method -eq 'ProcessStartInfo_NoShell' -or $method -eq 'ProcessStartInfo_Shell') {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $FilePath
                $psi.Arguments = $Arguments
                if ($WorkDir) { $psi.WorkingDirectory = $WorkDir }
                if ($method -eq 'ProcessStartInfo_NoShell') {
                    $psi.UseShellExecute = $false
                    $psi.CreateNoWindow = (-not $ShowWindow)
                }
                else {
                    $psi.UseShellExecute = $true
                    if (-not $ShowWindow) { $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden }
                }
                $p = New-Object System.Diagnostics.Process
                $p.StartInfo = $psi
                if (-not $p.Start()) { throw 'Start returned false' }
            }
            elseif ($method -eq 'Start-Process') {
                $sp = @{
                    FilePath     = $FilePath
                    PassThru     = $true
                    ErrorAction  = 'Stop'
                }
                # 整串交给 Arguments 风格：用 cmd 更稳；此处拆成无引号片段作兜底
                if ($Arguments) {
                    $parts = @()
                    if ($Arguments -match '^"([^"]+)"\s*(.*)$') {
                        $parts += $matches[1]
                        if ($matches[2]) {
                            foreach ($t in ($matches[2] -split '\s+')) {
                                if ($t) { $parts += $t }
                            }
                        }
                    }
                    else {
                        $parts = @($Arguments)
                    }
                    $sp['ArgumentList'] = $parts
                }
                if ($WorkDir) { $sp['WorkingDirectory'] = $WorkDir }
                if (-not $ShowWindow) { $sp['WindowStyle'] = 'Hidden' }
                $p = Start-Process @sp
            }
            elseif ($method -eq 'cmd_start') {
                if (-not $Arguments) {
                    if ($baseName -ieq 'wusa.exe') { throw '拒绝无参 wusa' }
                    $cmdArgs = '/c start /wait "" "' + $FilePath + '"'
                }
                else {
                    $cmdArgs = '/c ""' + $FilePath + '" ' + $Arguments + '"'
                }
                $p = Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdArgs -PassThru -WindowStyle Hidden -ErrorAction Stop
            }

            if (-not $p) { throw '未能创建进程' }

            $start = Get-Date
            while (-not $p.HasExited) {
                $elapsed = [int]((Get-Date) - $start).TotalSeconds
                if ($Progress) {
                    try {
                        & $Progress ("{0}（{1} · 已用时 {2}s · 请勿强制关闭）" -f $ProgressText, $method, $elapsed)
                    }
                    catch { }
                }
                try { [System.Windows.Forms.Application]::DoEvents() } catch { }
                Start-Sleep -Milliseconds 250
                if ($elapsed -ge $TimeoutSec) {
                    try { $p.Kill() } catch { }
                    throw '超时'
                }
            }
            return $p.ExitCode
        }
        catch {
            $lastErr = $_.Exception.Message
            # try next method
        }
    }
    throw ("进程启动全部失败: {0} | {1}" -f $FilePath, $lastErr)
}

function Save-OrDownload {
    param(
        [string]$Url,
        [string]$Destination,
        [scriptblock]$Progress = $null
    )
    $dir = Split-Path -Parent $Destination
    [void](New-OrDirectory $dir)
    if (Test-OrPath $Destination) {
        try { Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue } catch { }
    }

    $errors = @()

    # 1) curl bundled / system
    $curlCandidates = @()
    if ($script:OpenRuntimeRoot) {
        $curlCandidates += (Join-Path $script:OpenRuntimeRoot 'tools\curl\curl.exe')
        $curlCandidates += (Join-Path $script:OpenRuntimeRoot 'tools\curl\bin\curl.exe')
    }
    $curlCandidates += (Join-Path $env:SystemRoot 'System32\curl.exe')
    $curl = $null
    foreach ($c in $curlCandidates) {
        if (Test-OrPath $c) { $curl = $c; break }
    }
    if ($curl) {
        try {
            Write-OrTryLog '下载方法1: curl' $Progress
            $ca = Join-Path (Split-Path -Parent $curl) 'curl-ca-bundle.crt'
            $argList = @('-L', '--retry', '3', '--connect-timeout', '30', '-o', $Destination, $Url)
            if (Test-OrPath $ca) { $argList = @('--cacert', $ca) + $argList }
            $p = Start-Process -FilePath $curl -ArgumentList $argList -Wait -PassThru -WindowStyle Hidden
            if (($p.ExitCode -eq 0) -and (Test-OrFileOk $Destination)) { return 'curl' }
            $errors += ("curl exit " + $p.ExitCode)
        }
        catch { $errors += $_.Exception.Message }
    }

    # 2) BITS
    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        try {
            Write-OrTryLog '下载方法2: BITS' $Progress
            Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
            if (Test-OrFileOk $Destination) { return 'BITS' }
        }
        catch { $errors += $_.Exception.Message }
    }

    # 3) WebClient TLS 3072
    try {
        Write-OrTryLog '下载方法3: WebClient' $Progress
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        }
        catch {
            try { [Net.ServicePointManager]::SecurityProtocol = 3072 } catch { }
        }
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'OpenRuntime/1.3')
        $wc.DownloadFile($Url, $Destination)
        try { $wc.Dispose() } catch { }
        if (Test-OrFileOk $Destination) { return 'WebClient' }
    }
    catch { $errors += $_.Exception.Message }

    # 4) certutil
    $certutil = Join-Path $env:SystemRoot 'System32\certutil.exe'
    if (Test-OrPath $certutil) {
        try {
            Write-OrTryLog '下载方法4: certutil' $Progress
            $p = Start-Process -FilePath $certutil -ArgumentList @('-urlcache', '-split', '-f', $Url, $Destination) -Wait -PassThru -WindowStyle Hidden
            if (Test-OrFileOk $Destination) { return 'certutil' }
            $errors += ("certutil exit " + $p.ExitCode)
        }
        catch { $errors += $_.Exception.Message }
    }

    # 5) bitsadmin (very old)
    $bitsadmin = Join-Path $env:SystemRoot 'System32\bitsadmin.exe'
    if (Test-OrPath $bitsadmin) {
        try {
            Write-OrTryLog '下载方法5: bitsadmin' $Progress
            $job = 'OpenRuntimeJob'
            cmd /c "bitsadmin /cancel $job" >$null 2>&1
            cmd /c "bitsadmin /create /download $job" >$null 2>&1
            cmd /c "bitsadmin /addfile $job `"$Url`" `"$Destination`"" >$null 2>&1
            cmd /c "bitsadmin /resume $job" >$null 2>&1
            $deadline = (Get-Date).AddMinutes(30)
            while ((Get-Date) -lt $deadline) {
                Start-Sleep -Seconds 2
                if (Test-OrFileOk $Destination) { break }
                $st = cmd /c "bitsadmin /info $job /verbose" 2>&1 | Out-String
                if ($st -match 'STATE: TRANSFERRED') {
                    cmd /c "bitsadmin /complete $job" >$null 2>&1
                    break
                }
                if ($st -match 'ERROR|CANCELLED') { break }
            }
            cmd /c "bitsadmin /complete $job" >$null 2>&1
            if (Test-OrFileOk $Destination) { return 'bitsadmin' }
        }
        catch { $errors += $_.Exception.Message }
    }

    throw ("下载失败（已轮询 curl/BITS/WebClient/certutil/bitsadmin）: " + ($errors -join ' | '))
}

function Invoke-OrRetry {
    param(
        [scriptblock]$Script,
        [int]$Times = 3,
        [int]$DelaySec = 2,
        [scriptblock]$Progress = $null,
        [string]$Label = '操作'
    )
    $last = $null
    for ($i = 1; $i -le $Times; $i++) {
        try {
            if ($Progress) { & $Progress ("{0}（第 {1}/{2} 次尝试）" -f $Label, $i, $Times) }
            return & $Script
        }
        catch {
            $last = $_
            Start-Sleep -Seconds $DelaySec
        }
    }
    throw $last
}

# ---- MSU / CAB：Windows Update 禁用时绕过 wusa（0x80070422）----

function Test-OrWuauservUsable {
    # 不修改服务状态；仅探测是否可能被禁用
    try {
        $svc = Get-Service -Name 'wuauserv' -ErrorAction Stop
        try {
            if ($svc.StartType -eq 'Disabled') { return $false }
        }
        catch { }
    }
    catch { }
    try {
        $qc = & sc.exe qc wuauserv 2>&1 | Out-String
        if ($qc -match 'DISABLED') { return $false }
    }
    catch { }
    return $true
}

function Get-OrSystemExe {
    param([string]$Name)
    $candidates = @(
        (Join-Path $env:SystemRoot ('Sysnative\' + $Name)),
        (Join-Path $env:SystemRoot ('System32\' + $Name))
    )
    foreach ($c in $candidates) {
        if (Test-OrPath $c) { return $c }
    }
    return $null
}

function Start-OrExeWait {
    param(
        [string]$FilePath,
        [string]$Arguments,
        [scriptblock]$Progress = $null,
        [string]$ProgressText = '安装中…',
        [int]$TimeoutSec = 7200
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    if (-not $p.Start()) { throw 'Start returned false' }
    $start = Get-Date
    while (-not $p.HasExited) {
        $elapsed = [int]((Get-Date) - $start).TotalSeconds
        if ($Progress) {
            try { & $Progress ("{0} {1}s" -f $ProgressText, $elapsed) } catch { }
        }
        try { [System.Windows.Forms.Application]::DoEvents() } catch { }
        Start-Sleep -Milliseconds 300
        if ($elapsed -gt $TimeoutSec) {
            try { $p.Kill() } catch { }
            throw '超时'
        }
    }
    return $p.ExitCode
}

function Expand-OrMsu {
    param(
        [string]$MsuPath,
        [string]$Destination,
        [scriptblock]$Progress = $null
    )
    if (Test-OrPath $Destination) {
        try { Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }
    [void](New-OrDirectory $Destination)

    $expand = Get-OrSystemExe 'expand.exe'
    if ($expand) {
        if ($Progress) { & $Progress 'expand 解包 MSU（不依赖 Windows Update）…' }
        $args = '-F:* "' + $MsuPath + '" "' + $Destination + '"'
        $code = Start-OrExeWait -FilePath $expand -Arguments $args -Progress $Progress -ProgressText '解包 MSU…' -TimeoutSec 600
        $cabs = @(Get-OrChildFiles -Path $Destination -Filter '*.cab' -Recurse)
        if ($cabs.Count -gt 0) { return $Destination }
    }

    # wusa /extract 通常只解包，多数机器在服务禁用时仍可用
    $wusa = Get-OrSystemExe 'wusa.exe'
    if ($wusa) {
        if ($Progress) { & $Progress 'wusa /extract 解包…' }
        $args = '"' + $MsuPath + '" /extract:"' + $Destination + '"'
        try {
            [void](Start-OrExeWait -FilePath $wusa -Arguments $args -Progress $Progress -ProgressText '解包…' -TimeoutSec 600)
        }
        catch { }
        $cabs = @(Get-OrChildFiles -Path $Destination -Filter '*.cab' -Recurse)
        if ($cabs.Count -gt 0) { return $Destination }
    }

    throw 'MSU 解包失败（expand/wusa /extract）'
}

function Get-OrMsuCabInstallOrder {
    <#
      WMF 5.1 的 MSU 含多个 CAB（前置补丁 + KB3191566），必须按 PkgInstallOrder.txt 顺序全部装完。
      旧逻辑装完第一个就 return，会导致“显示成功但 PowerShell 仍是 2.0”。
    #>
    param([string]$Folder)
    $ordered = @()
    $orderFile = Join-Path $Folder 'PkgInstallOrder.txt'
    if (Test-OrPath $orderFile) {
        try {
            $lines = Get-Content -LiteralPath $orderFile -ErrorAction SilentlyContinue
            foreach ($line in @($lines)) {
                if ($line -match '^\s*\d+\s*=\s*(.+\.cab)\s*$') {
                    $name = $Matches[1].Trim()
                    $full = Join-Path $Folder $name
                    if (Test-OrPath $full) {
                        $ordered += (Get-Item -LiteralPath $full)
                    }
                }
            }
        }
        catch { }
    }
    if ($ordered.Count -gt 0) { return $ordered }

    # 无顺序文件时：前置 KB 在前，主包（KB3191566 / KB3191564）在最后
    $all = @(Get-OrChildFiles -Path $Folder -Filter '*.cab' -Recurse)
    $main = @()
    $pre = @()
    foreach ($f in $all) {
        if ($f.Name -match 'WSUSSCAN') { continue }
        if ($f.Name -notmatch '\.cab$') { continue }
        if ($f.Name -match 'KB3191566|KB3191564|KB3191565') { $main += $f }
        elseif ($f.Name -match '^Windows6\.|^Windows8\.|KB\d+') { $pre += $f }
    }
    return @($pre + $main)
}

function Test-OrExitOk {
    param([int]$Code)
    foreach ($c in @(0, 3010, 2359302, 1638)) {
        if ($Code -eq $c) { return $true }
    }
    return $false
}

function Start-OrTrustedInstaller {
    # Windows Modules Installer — 不是 wuauserv，不碰“Windows Update”禁用状态
    param([scriptblock]$Progress = $null)
    try {
        $svc = Get-Service -Name 'TrustedInstaller' -ErrorAction SilentlyContinue
        if (-not $svc) { return }
        if ($svc.Status -eq 'Running') { return }
        if ($Progress) { & $Progress '启动 TrustedInstaller（Windows 模块安装程序，非更新服务）…' }
        try { Start-Service -Name 'TrustedInstaller' -ErrorAction SilentlyContinue } catch { }
        try { & sc.exe start TrustedInstaller | Out-Null } catch { }
    }
    catch { }
}

function Install-OrCabPackage {
    param(
        [string]$CabPath,
        [scriptblock]$Progress = $null
    )
    if (-not (Test-OrFileOk $CabPath)) {
        throw ("CAB 无效: " + $CabPath)
    }

    Start-OrTrustedInstaller -Progress $Progress
    $last = -1
    $log = Join-Path $env:TEMP ('OpenRuntime_DISM_' + [System.IO.Path]::GetFileNameWithoutExtension($CabPath) + '.log')

    $dism = Get-OrSystemExe 'dism.exe'
    if ($dism) {
        # Win7 DISM 不一定支持 /Quiet；用 /NoRestart + 日志
        $argSets = @(
            ('/Online /Add-Package /PackagePath:"{0}" /NoRestart /LogPath:"{1}"' -f $CabPath, $log),
            ('/Online /Add-Package /PackagePath:"{0}" /NoRestart' -f $CabPath)
        )
        foreach ($a in $argSets) {
            try {
                if ($Progress) { & $Progress ('DISM: ' + [System.IO.Path]::GetFileName($CabPath)) }
                $last = Start-OrExeWait -FilePath $dism -Arguments $a -Progress $Progress -ProgressText ('DISM ' + [System.IO.Path]::GetFileName($CabPath)) -TimeoutSec 7200
                if (Test-OrExitOk $last) { return $last }
                if ($Progress) { & $Progress ("DISM 退出码 {0}（{1}）" -f $last, [System.IO.Path]::GetFileName($CabPath)) }
            }
            catch { $last = -1 }
        }
    }

    $pkgmgr = Get-OrSystemExe 'pkgmgr.exe'
    if ($pkgmgr) {
        foreach ($a in @(
            ('/ip /m:"{0}" /quiet /norestart' -f $CabPath),
            ('/ip /m:"{0}" /quiet' -f $CabPath)
        )) {
            try {
                if ($Progress) { & $Progress ('pkgmgr: ' + [System.IO.Path]::GetFileName($CabPath)) }
                $last = Start-OrExeWait -FilePath $pkgmgr -Arguments $a -Progress $Progress -ProgressText 'pkgmgr…' -TimeoutSec 7200
                if (Test-OrExitOk $last) { return $last }
            }
            catch { $last = -1 }
        }
    }

    return $last
}

function Install-OrMsu {
    <#
      安装 .msu：
      - Update 可用时先试 wusa（一次装齐整包）
      - 否则 expand 后按 PkgInstallOrder 依次 DISM 所有 CAB（不改 wuauserv）
    #>
    param(
        [string]$MsuPath,
        [scriptblock]$Progress = $null
    )
    if (-not (Test-OrFileOk $MsuPath)) {
        throw ("MSU 文件无效: " + $MsuPath)
    }

    $last = -1
    $wuOk = Test-OrWuauservUsable
    $needReboot = $false

    if ($wuOk) {
        if ($Progress) { & $Progress '尝试 wusa 静默安装（整包）…' }
        $wusa = Get-OrSystemExe 'wusa.exe'
        if ($wusa) {
            foreach ($a in @(
                ('"{0}" /quiet /norestart' -f $MsuPath),
                ('"{0}" /quiet' -f $MsuPath)
            )) {
                try {
                    if ($Progress) { & $Progress ('wusa: ' + $a) }
                    $last = Start-OrExeWait -FilePath $wusa -Arguments $a -Progress $Progress -ProgressText 'wusa…' -TimeoutSec 7200
                    if (Test-OrExitOk $last) { return $last }
                    if ($last -eq -2147023838 -or $last -eq 1058 -or $last -eq 2147943458) { break }
                }
                catch { $last = -1 }
            }
        }
    }
    else {
        if ($Progress) { & $Progress 'Windows Update 已禁用 → 不解禁，改用 expand + 按顺序安装全部 CAB' }
    }

    $extract = Join-Path $env:TEMP ('OpenRuntime_MSU_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        if ($Progress) { & $Progress '解包 MSU（含多个前置补丁 + 主包）…' }
        Expand-OrMsu -MsuPath $MsuPath -Destination $extract -Progress $Progress | Out-Null
        $cabs = @(Get-OrMsuCabInstallOrder -Folder $extract)
        if ($cabs.Count -eq 0) {
            throw '解包后未找到可安装的 .cab'
        }

        if ($Progress) {
            & $Progress ('将按顺序安装 {0} 个 CAB（必须全部完成，不能只装第一个）' -f $cabs.Count)
        }

        $mainOk = $false
        $anyOk = $false
        $idx = 0
        foreach ($cab in $cabs) {
            $idx++
            $isMain = ($cab.Name -match 'KB3191566|KB3191564|KB3191565')
            if ($Progress) {
                & $Progress ("[{0}/{1}] {2}{3}" -f $idx, $cabs.Count, $cab.Name, $(if ($isMain) { ' ← 主包(PowerShell 5.1)' } else { '（前置）' }))
            }
            $last = Install-OrCabPackage -CabPath $cab.FullName -Progress $Progress
            if (Test-OrExitOk $last) {
                $anyOk = $true
                if ($last -eq 3010) { $needReboot = $true }
                if ($isMain) { $mainOk = $true }
                if ($Progress) { & $Progress ("  OK 退出码 {0}" -f $last) }
            }
            else {
                # 前置失败：仍继续试后面；主包失败则记失败
                if ($Progress) { & $Progress ("  失败 退出码 {0}" -f $last) }
                if ($isMain) { $mainOk = $false }
            }
        }

        if ($mainOk) {
            if ($needReboot) { return 3010 }
            return 0
        }
        # 没有明确主包名时，全部成功才算成功
        if ($anyOk -and $cabs.Count -gt 0) {
            $allNamed = $false
            foreach ($cab in $cabs) {
                if ($cab.Name -match 'KB3191566|KB3191564|KB3191565') { $allNamed = $true; break }
            }
            if (-not $allNamed) {
                if ($needReboot) { return 3010 }
                return 0
            }
        }
        if ($Progress) {
            & $Progress '主包 KB3191566/1564 未成功安装。请确认 .NET 4.5+ 已装，并查看 %TEMP%\OpenRuntime_DISM_*.log'
        }
    }
    finally {
        try { Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }

    return $last
}

# ---- WMF 5.1 / PowerShell 5.1 真实状态 ----

function Test-OrVersionAtLeast51 {
    param([string]$Text)
    if (-not $Text) { return $false }
    if ($Text -match '(\d+)\.(\d+)') {
        $maj = [int]$Matches[1]
        $min = [int]$Matches[2]
        if ($maj -gt 5) { return $true }
        if ($maj -eq 5 -and $min -ge 1) { return $true }
    }
    return $false
}

function Get-OrPowerShellRealVersion {
    # 新开 powershell.exe 读取系统实际生效的版本；读不到返回 $null
    $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-OrPath $exe)) { return $null }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$PSVersionTable.PSVersion.ToString()"'
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $out = $p.StandardOutput.ReadToEnd()
        [void]$p.WaitForExit(30000)
        if ($out -match '(\d+\.\d+)') { return $Matches[1] }
    }
    catch { }
    return $null
}

function Get-OrCbsPackageState {
    # CBS CurrentState: 64=Staged 96=Install Pending 101=Partially Installed 112=Installed 128=Permanent
    # 只有键名存在不代表已安装（Staged / 失败残留也会留下键）
    param([string]$KbPattern)
    $cbs = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'
    $best = -1
    try {
        foreach ($k in @(Get-ChildItem -LiteralPath $cbs -ErrorAction SilentlyContinue)) {
            if ($k.PSChildName -notmatch $KbPattern) { continue }
            try {
                $st = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop).CurrentState
                if ($null -ne $st) {
                    $st = [int]$st
                    if ($st -gt $best) { $best = $st }
                }
            }
            catch { }
        }
    }
    catch { }
    return $best
}

function Get-OrWmf51State {
    # Active        = 系统里的 powershell.exe 已经是 5.1+
    # PendingReboot = KB3191566/1564 已进入 CBS 安装/待安装状态，但还没生效
    # NotInstalled  = 其它一切情况（含只解包/Staged/失败残留）
    try {
        $v = $PSVersionTable.PSVersion
        if ($v.Major -gt 5 -or ($v.Major -eq 5 -and $v.Minor -ge 1)) { return 'Active' }
    }
    catch { }

    if (Test-OrVersionAtLeast51 (Get-OrPowerShellRealVersion)) { return 'Active' }

    $st = Get-OrCbsPackageState -KbPattern 'KB3191566|KB3191564|KB3191565'
    if ($st -eq 96 -or $st -eq 101 -or $st -eq 112 -or $st -eq 128) { return 'PendingReboot' }

    return 'NotInstalled'
}
