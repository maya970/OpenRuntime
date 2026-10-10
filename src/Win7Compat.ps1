# OpenRuntime — 让 Win7 运行需要 Win8/10 API 的程序（扫描缺失函数 + 用 VxKex 官方 KexCfg 启用）
# 依赖：Robust.ps1、Core.ps1、Extra.ps1、PeScan.ps1

function Test-OrIsWin7 {
    $v = [Environment]::OSVersion.Version
    return ($v.Major -eq 6 -and $v.Minor -eq 1)
}

function Get-OrVxKexCfgPath {
    $dirs = @()
    $d = Get-VxKexInstallDir
    if ($d) { $dirs += $d }
    $dirs += @((Join-Path $env:ProgramFiles 'VxKex'), 'C:\Program Files\VxKex', 'C:\Program Files (x86)\VxKex')
    foreach ($dir in $dirs) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $direct = Join-Path $dir 'KexCfg.exe'
        if (Test-Path -LiteralPath $direct) { return $direct }
        $hit = Get-OrChildFiles -Path $dir -Filter 'KexCfg.exe' -Recurse | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

$script:OrVxKexExportSet = $null
function Get-OrVxKexExportSet {
    # VxKex 各 Kx*.dll 导出的函数名并集（用于判断缺失的函数 VxKex 能否补上）
    if ($script:OrVxKexExportSet) { return $script:OrVxKexExportSet }
    $set = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)
    $cfg = Get-OrVxKexCfgPath
    if ($cfg) {
        $root = Split-Path -Parent $cfg
        foreach ($f in @(Get-OrChildFiles -Path $root -Filter 'Kx*.dll' -Recurse)) {
            $ex = Get-OrPeExports $f.FullName
            if (-not $ex.Exports) { continue }
            foreach ($n in $ex.Exports.Keys) { $set[$n] = $true }
        }
    }
    $script:OrVxKexExportSet = $set
    return $set
}

function Get-OrVxKexIfeoState([string]$ExePath) {
    $name = [System.IO.Path]::GetFileName($ExePath)
    $base = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\' + $name
    $dump = @{}
    $enabled = $false
    if (Test-Path -LiteralPath $base) {
        $keys = @(Get-Item -LiteralPath $base) + @(Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue)
        foreach ($k in $keys) {
            $vals = @{}
            $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
            if ($p) {
                foreach ($pr in $p.PSObject.Properties) {
                    if ($pr.Name -notmatch '^PS') { $vals[$pr.Name] = [string]$pr.Value }
                }
            }
            $dump[$k.PSChildName] = $vals
            if ([string]$vals['VerifierDlls'] -match 'kexdll') {
                $fp = [string]$vals['FilterFullPath']
                if (-not $fp -or $fp.ToLower().EndsWith($ExePath.ToLower())) { $enabled = $true }
            }
        }
    }
    return @{ Enabled = $enabled; Dump = $dump }
}

function Enable-OrVxKexForExe {
    param(
        [string]$ExePath,
        [string]$KexCfg,
        [scriptblock]$Progress = $null
    )
    $code = -1
    $err = $null
    try {
        $cfgArgs = '/EXE:"' + $ExePath + '" /ENABLE:1 /DISABLEFORCHILD:0'
        $code = Start-OrExeWait -FilePath $KexCfg -Arguments $cfgArgs -Progress $Progress -ProgressText ('启用 VxKex: ' + [System.IO.Path]::GetFileName($ExePath)) -TimeoutSec 120
    }
    catch { $err = $_.Exception.Message }
    if ($err -and $Progress) { & $Progress ('KexCfg 出错: ' + $err) }
    $state = Get-OrVxKexIfeoState $ExePath
    return $state.Enabled
}

function Get-OrWin7AppTargets([string]$Path) {
    $item = Get-Item -LiteralPath $Path
    $main = $null
    if ($item.PSIsContainer) { $dir = $item.FullName }
    else { $dir = $item.DirectoryName; $main = $item }

    # 桌面/下载/盘符根目录等杂物文件夹：只处理选中的那个程序，避免误伤其它软件
    $broad = ($dir.TrimEnd('\').Length -le 3)
    foreach ($s in @(
            [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyDocuments'),
            (Join-Path $env:USERPROFILE 'Downloads'), $env:USERPROFILE, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:SystemRoot)) {
        if ($s -and ($dir.TrimEnd('\') -ieq $s.TrimEnd('\'))) { $broad = $true }
    }

    $exes = @(); $libs = @()
    if ($broad) {
        if ($main) { $exes = @($main) }
        $libs = @(Get-ChildItem -LiteralPath $dir -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and ($_.Extension -match '^\.(dll|node)$') } | Select-Object -First 200)
    }
    else {
        $all = @(Get-ChildItem -LiteralPath $dir -Recurse -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and ($_.Extension -match '^\.(exe|dll|node)$') } | Select-Object -First 2000)
        $exes = @($all | Where-Object { $_.Extension -eq '.exe' } | Select-Object -First 60)
        $libs = @($all | Where-Object { $_.Extension -ne '.exe' } | Select-Object -First 400)
        if ($main -and -not (@($exes | Where-Object { $_.FullName -eq $main.FullName }).Count)) { $exes = @($main) + $exes }
    }
    return @{ Dir = $dir; Exes = $exes; Libs = $libs; Broad = $broad }
}

function Repair-OrWin7App {
    param(
        [string]$Path,
        [scriptblock]$Progress = $null
    )
    $res = New-Object PSObject -Property @{ Ok = $false; Message = ''; Uncovered = @(); Enabled = @(); Failed = @(); MissingCount = 0 }

    if (-not (Test-OrIsWin7)) { $res.Message = '当前系统不是 Windows 7，不需要这项修复。'; return $res }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { $res.Message = '找不到所选程序。'; return $res }

    if ($Progress) { & $Progress '分析程序及同目录文件需要哪些系统函数…' }
    $t = Get-OrWin7AppTargets $Path
    if ($t.Exes.Count -eq 0) { $res.Message = '所选位置没有可修复的 exe 程序。'; return $res }

    $missing = Find-OrMissingImports -Files @($t.Exes + $t.Libs)
    $res.MissingCount = @($missing).Count
    foreach ($m in $missing) {
        if ($Progress) { & $Progress ('Win7 缺少: ' + [System.IO.Path]::GetFileName($m.File) + ' → ' + $m.Dll + ' : ' + (@($m.Functions | Select-Object -First 6) -join ', ')) }
    }

    if (-not (Test-VxKexInstalled)) {
        if ($Progress) { & $Progress '未安装 VxKex，正在安装…' }
        $item = $null
        foreach ($c in (Get-OpenRuntimeCatalog)) { if ($c.Special -eq 'VxKex') { $item = $c } }
        if ($item) { [void](Install-OpenRuntimeItem -Item $item -Progress $Progress) }
    }
    $kexCfg = Get-OrVxKexCfgPath
    if (-not $kexCfg) { $res.Message = 'VxKex 未能安装（找不到 KexCfg.exe），无法修复。'; return $res }

    $kexSet = Get-OrVxKexExportSet
    $uncovered = @(); $soft = @()
    foreach ($m in $missing) {
        if ($m.Dll -match '^api-ms-') { continue }
        foreach ($fn in $m.Functions) {
            if ($fn.StartsWith('#')) { continue }
            if ($kexSet.ContainsKey($fn)) { continue }
            # 延迟加载的函数只在真正调用时才解析，不影响程序启动
            if ($m.Delay) { $soft += ($m.Dll + '!' + $fn) } else { $uncovered += ($m.Dll + '!' + $fn) }
        }
    }
    $res.Uncovered = @($uncovered | Select-Object -Unique)
    $soft = @($soft | Select-Object -Unique)

    $winDir = $env:SystemRoot.TrimEnd('\') + '\'
    foreach ($exe in $t.Exes) {
        if ($exe.FullName.StartsWith($winDir, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($exe.FullName.Length -ge 250 -or $exe.FullName -notmatch '^[A-Za-z]:\\') { $res.Failed += $exe.Name; continue }
        if (Enable-OrVxKexForExe -ExePath $exe.FullName -KexCfg $kexCfg -Progress $Progress) { $res.Enabled += $exe.Name }
        else { $res.Failed += $exe.Name }
    }

    $res.Ok = ($res.Enabled.Count -gt 0 -and $res.Failed.Count -eq 0)
    $msg = ('已为 {0} 个程序启用 VxKex。' -f $res.Enabled.Count)
    if ($res.Failed.Count -gt 0) { $msg += ("`n启用失败：" + ($res.Failed -join ', ')) }
    if ($res.MissingCount -eq 0) { $msg += "`n未发现缺失的系统函数；若仍打不开，问题可能不在系统 API。" }
    if ($res.Uncovered.Count -gt 0) {
        $msg += ("`n以下函数 VxKex 也没有提供，程序可能仍无法运行，建议换该软件的 Win7 版本：`n" + (@($res.Uncovered | Select-Object -First 10) -join "`n"))
    }
    if ($soft.Count -gt 0) {
        $msg += ("`n（另有 {0} 个函数为延迟加载，Win7 上没有，但一般不影响启动，仅个别功能可能不可用）" -f $soft.Count)
    }
    $res.Message = $msg
    return $res
}
