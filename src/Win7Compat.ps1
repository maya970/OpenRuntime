# OpenRuntime — 一键修复打不开的程序（Win7 跑新软件 / Win10 跑老游戏，同一按钮）
# 依赖：Robust.ps1、Core.ps1、Extra.ps1、PeScan.ps1

function Test-OrIsWin7 {
    $v = [Environment]::OSVersion.Version
    return ($v.Major -eq 6 -and $v.Minor -eq 1)
}

function Test-OrIsWin10Plus {
    return ([Environment]::OSVersion.Version.Major -ge 10)
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

function Install-OrWin7CompatBundle {
    # 小白只点一次「修复」：缺什么就自动装什么，不必再回列表点
    param([scriptblock]$Progress = $null)
    $steps = @(
        @{ Special = 'VxKex'; Need = { -not (Test-VxKexInstalled) }; Text = '正在安装兼容引擎…' },
        @{ Special = 'VulkanRuntime'; Need = { -not (Test-OrVulkanRuntimeInstalled) }; Text = '正在安装图形运行库…' },
        @{ Special = 'Dxvk'; Need = { -not (Test-OrDxvkInstalled) }; Text = '正在准备 Direct3D 兼容文件…' },
        @{ Special = 'Vkd3d'; Need = { -not (Test-OrVkd3dInstalled) }; Text = '正在准备 Direct3D 12 兼容文件…' }
    )
    foreach ($s in $steps) {
        $need = & $s.Need
        if (-not $need) { continue }
        $item = $null
        foreach ($c in (Get-OpenRuntimeCatalog)) { if ($c.Special -eq $s.Special) { $item = $c } }
        if (-not $item) { continue }
        if ($Progress) { & $Progress $s.Text }
        try { [void](Install-OpenRuntimeItem -Item $item -Progress $Progress) }
        catch { if ($Progress) { & $Progress ('这项跳过了，继续：' + $_.Exception.Message) } }
    }
}

function Install-OrWin10LegacyBundle {
    param([scriptblock]$Progress = $null)
    # DirectX June 2010：很多 Win7 游戏闪退就是缺这个
    if (-not (Test-DirectXJun2010Present)) {
        $item = $null
        foreach ($c in (Get-OpenRuntimeCatalog)) { if ($c.Special -eq 'DirectXCab') { $item = $c } }
        if ($item) {
            if ($Progress) { & $Progress '正在安装 DirectX（老游戏常用）…' }
            try { [void](Install-OpenRuntimeItem -Item $item -Progress $Progress) }
            catch { if ($Progress) { & $Progress ('DirectX 跳过：' + $_.Exception.Message) } }
        }
    }
    if (-not (Test-OrDgVoodooInstalled)) {
        $item = $null
        foreach ($c in (Get-OpenRuntimeCatalog)) { if ($c.Special -eq 'DgVoodoo') { $item = $c } }
        if ($item) {
            if ($Progress) { & $Progress '正在准备老游戏图形兼容…' }
            try { [void](Install-OpenRuntimeItem -Item $item -Progress $Progress) }
            catch { if ($Progress) { & $Progress ('图形兼容跳过：' + $_.Exception.Message) } }
        }
    }
    try { [void](Enable-OrDirectPlay -Progress $Progress) } catch { }
}

function Repair-OrWin10LegacyApp {
    # Win10/11 上：过山车大亨、遥远的世界等 Win7 老游戏点开闪退
    param(
        [string]$Path,
        [scriptblock]$Progress = $null
    )
    $res = New-Object PSObject -Property @{ Ok = $false; Message = ''; Uncovered = @(); Enabled = @(); Failed = @(); MissingCount = 0 }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { $res.Message = '找不到这个程序，请重新选一次。'; return $res }

    if ($Progress) { & $Progress '① 正在准备环境（只需等，不用再点别的）…' }
    Install-OrWin10LegacyBundle -Progress $Progress

    if ($Progress) { & $Progress '② 正在处理这个程序…' }
    $t = Get-OrWin7AppTargets $Path
    if ($t.Exes.Count -eq 0) { $res.Message = '这里没有可修复的程序文件。'; return $res }

    $winDir = $env:SystemRoot.TrimEnd('\') + '\'
    $didCompat = $false
    $didGfx = $false
    foreach ($exe in $t.Exes) {
        if ($exe.FullName.StartsWith($winDir, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($exe.FullName.Length -ge 250 -or $exe.FullName -notmatch '^[A-Za-z]:\\') { $res.Failed += $exe.Name; continue }
        if ($Progress) { & $Progress ('正在处理：' + $exe.Name) }

        # 兼容模式：按「Windows 7」跑（等价于右键属性→兼容性，但自动完成）
        if (Set-OrExeCompatLayer -ExePath $exe.FullName -Flags '~ WIN7RTM HIGHDPIAWARE') {
            $res.Enabled += $exe.Name
            $didCompat = $true
        }
        else { $res.Failed += $exe.Name }

        $pe = Read-OrPe -File $exe.FullName
        if ($pe.Ok) {
            $copied = Deploy-OrDgVoodooToDir -AppDir $exe.DirectoryName -Is64 $pe.Is64 -Progress $null
            if (@($copied).Count -gt 0) { $didGfx = $true }
        }
    }

    $res.Ok = ($res.Enabled.Count -gt 0)
    if ($Progress) { & $Progress '③ 做完了。' }

    if ($res.Ok) {
        $res.Message = "修好了。`n请直接双击运行刚才选的那个程序，不用再点别的。"
        if (-not $didGfx) {
            $res.Message += "`n`n若仍然闪退：确认 packages 里有 dgVoodoo2 压缩包，或以管理员再试一次。"
        }
        elseif (-not $didCompat) {
            $res.Message += "`n`n兼容模式没写上，但兼容文件已放入；请直接再试一次。"
        }
    }
    else {
        $res.Message = '这次没修好。请确认用管理员运行了本工具，packages 文件夹完整，然后再试一次。'
    }
    return $res
}

function Repair-OrCompatApp {
    # 对外统一入口：Win7 / Win10 同一套「选程序 → 自动修好」
    param(
        [string]$Path,
        [scriptblock]$Progress = $null
    )
    if (Test-OrIsWin7) { return (Repair-OrWin7OnlyApp -Path $Path -Progress $Progress) }
    if (Test-OrIsWin10Plus) { return (Repair-OrWin10LegacyApp -Path $Path -Progress $Progress) }
    $res = New-Object PSObject -Property @{ Ok = $false; Message = '当前系统暂不需要这项修复。'; Uncovered = @(); Enabled = @(); Failed = @(); MissingCount = 0 }
    return $res
}

# 旧名保留，内部改走统一入口
function Repair-OrWin7App {
    param(
        [string]$Path,
        [scriptblock]$Progress = $null
    )
    return (Repair-OrCompatApp -Path $Path -Progress $Progress)
}

function Repair-OrWin7OnlyApp {
    param(
        [string]$Path,
        [scriptblock]$Progress = $null
    )
    $res = New-Object PSObject -Property @{ Ok = $false; Message = ''; Uncovered = @(); Enabled = @(); Failed = @(); MissingCount = 0 }

    if (-not (Test-OrIsWin7)) { $res.Message = '当前不是 Windows 7，不用做这项修复。'; return $res }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { $res.Message = '找不到这个程序，请重新选一次。'; return $res }

    if ($Progress) { & $Progress '① 正在准备环境（只需等，不用再点别的）…' }
    Install-OrWin7CompatBundle -Progress $Progress

    $kexCfg = Get-OrVxKexCfgPath
    if (-not $kexCfg) {
        $res.Message = '环境没装好。请确认 packages 文件夹完整，或以管理员重新运行后再试一次。'
        return $res
    }

    if ($Progress) { & $Progress '② 正在检查并处理这个程序…' }
    $t = Get-OrWin7AppTargets $Path
    if ($t.Exes.Count -eq 0) { $res.Message = '这里没有可修复的程序文件。'; return $res }

    $missing = Find-OrMissingImports -Files @($t.Exes + $t.Libs)
    $res.MissingCount = @($missing).Count

    $kexSet = Get-OrVxKexExportSet
    $uncovered = @()
    foreach ($m in $missing) {
        if ($m.Dll -match '^api-ms-') { continue }
        foreach ($fn in $m.Functions) {
            if ($fn.StartsWith('#')) { continue }
            if ($kexSet.ContainsKey($fn)) { continue }
            if ($m.Delay) { continue }
            $uncovered += ($m.Dll + '!' + $fn)
        }
    }
    $res.Uncovered = @($uncovered | Select-Object -Unique)

    $winDir = $env:SystemRoot.TrimEnd('\') + '\'
    $gfxOk = $false
    foreach ($exe in $t.Exes) {
        if ($exe.FullName.StartsWith($winDir, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($exe.FullName.Length -ge 250 -or $exe.FullName -notmatch '^[A-Za-z]:\\') { $res.Failed += $exe.Name; continue }
        if ($Progress) { & $Progress ('正在处理：' + $exe.Name) }
        if (Enable-OrVxKexForExe -ExePath $exe.FullName -KexCfg $kexCfg -Progress $null) { $res.Enabled += $exe.Name }
        else { $res.Failed += $exe.Name }

        $pe = Read-OrPe -File $exe.FullName
        if ($pe.Ok) {
            $copied = Deploy-OrGfxDllsToDir -AppDir $exe.DirectoryName -Is64 $pe.Is64 -Progress $null
            if (@($copied).Count -gt 0) { $gfxOk = $true }
        }
    }

    $res.Ok = ($res.Enabled.Count -gt 0 -and $res.Failed.Count -eq 0)
    if ($Progress) { & $Progress '③ 做完了。' }

    if ($res.Ok) {
        $res.Message = "修好了。`n请直接双击运行刚才选的那个程序，不用再点别的。"
        if ($gfxOk -and -not (Test-OrVulkanRuntimeInstalled)) {
            $res.Message += "`n`n若打开后是黑屏：请到显卡官网装一个带 Vulkan 的 Win7 驱动，再双击运行一次。"
        }
    }
    elseif ($res.Enabled.Count -gt 0) {
        $res.Message = "部分程序已处理。`n请先双击试一下能开的；不行再换该软件的 Win7 版本。"
    }
    else {
        $res.Message = '这次没修好。请确认用管理员运行了本工具，packages 文件夹完整，然后再试一次。'
    }
    return $res
}
