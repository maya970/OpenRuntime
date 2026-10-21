# OpenRuntime — VxKex / Locale / Win7 Vulkan·DXVK·vkd3d / Win10 老游戏 dgVoodoo (no new UI)
# Compatible with Windows PowerShell 2.0+

function Get-OrGfxRoot {
    return (Join-Path $env:ProgramFiles 'OpenRuntime')
}

function Get-OrDxvkDir {
    $d = Join-Path (Get-OrGfxRoot) 'DXVK'
    if (Test-Path -LiteralPath (Join-Path $d 'x64\d3d11.dll')) { return $d }
    if (Test-Path -LiteralPath (Join-Path $d 'x32\d3d11.dll')) { return $d }
    return $null
}

function Get-OrVkd3dDir {
    $d = Join-Path (Get-OrGfxRoot) 'vkd3d'
    if (Test-Path -LiteralPath (Join-Path $d 'x64\d3d12.dll')) { return $d }
    if (Test-Path -LiteralPath (Join-Path $d 'x86\d3d12.dll')) { return $d }
    return $null
}

function Test-OrVulkanRuntimeInstalled {
    $sys = Join-Path $env:SystemRoot 'System32\vulkan-1.dll'
    if (Test-Path -LiteralPath $sys) { return $true }
    $wow = Join-Path $env:SystemRoot 'SysWOW64\vulkan-1.dll'
    if (Test-Path -LiteralPath $wow) { return $true }
    $u = Get-UninstallEntries
    foreach ($e in $u) {
        if ($e.DisplayName -match 'Vulkan Runtime') { return $true }
    }
    return $false
}

function Test-OrDxvkInstalled {
    return [bool](Get-OrDxvkDir)
}

function Test-OrVkd3dInstalled {
    return [bool](Get-OrVkd3dDir)
}

function Install-OrVulkanRuntimePackage {
    param(
        [string]$SetupPath,
        [scriptblock]$Progress = $null
    )
    if (-not (Test-Path -LiteralPath $SetupPath)) {
        throw '找不到 Vulkan Runtime 安装包'
    }
    if ($Progress) { & $Progress '正在静默安装 Vulkan Runtime（Win7 最后可用版 1.2.198.1）...' }
    $code = -1
    foreach ($arg in @('/S', '/silent', '/VERYSILENT /NORESTART', '')) {
        try {
            if ($Progress) { & $Progress ('VulkanRT 参数: ' + $arg) }
            $code = Start-OrProcess -FilePath $SetupPath -Arguments $arg -Progress $Progress -ProgressText '正在安装 Vulkan Runtime' -TimeoutSec 600
            if (Test-OrVulkanRuntimeInstalled) { return 0 }
            if ($code -eq 0 -or $code -eq 3010) { break }
        }
        catch { $code = -1 }
    }
    if (Test-OrVulkanRuntimeInstalled) { return 0 }
    return $code
}

function Install-OrZipToGfxDir {
    param(
        [string]$ZipPath,
        [string]$TargetName,
        [string]$ProbeRelative,
        [string]$ProgressText,
        [scriptblock]$Progress = $null
    )
    if (-not (Test-Path -LiteralPath $ZipPath)) {
        throw ("找不到压缩包：" + $ZipPath)
    }
    $root = Get-OrGfxRoot
    $target = Join-Path $root $TargetName
    if ($Progress) { & $Progress $ProgressText }
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $target -Force | Out-Null

    $tmp = Join-Path $env:TEMP ('OR_gfx_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        Expand-OrArchive -ZipPath $ZipPath -Destination $tmp -Progress $Progress | Out-Null
        $srcRoot = $tmp
        # 优先：探测相对路径在解压根下直接成立（如 MS\x86\D3D9.dll、x64\d3d11.dll）
        if (-not (Test-Path -LiteralPath (Join-Path $tmp $ProbeRelative))) {
            $probeName = [System.IO.Path]::GetFileName($ProbeRelative)
            $hit = Get-OrChildFiles -Path $tmp -Filter $probeName -Recurse | Select-Object -First 1
            if ($hit) {
                $cand = $hit.DirectoryName
                while ($cand -and $cand.Length -gt 3) {
                    if (Test-Path -LiteralPath (Join-Path $cand $ProbeRelative)) { $srcRoot = $cand; break }
                    $parent = Split-Path -Parent $cand
                    if ($parent -eq $cand) { break }
                    $cand = $parent
                }
                if (-not (Test-Path -LiteralPath (Join-Path $srcRoot $ProbeRelative))) {
                    $dir = $hit.DirectoryName
                    if ($dir -match '\\(x64|x32|x86)$') { $srcRoot = Split-Path -Parent $dir }
                    else { $srcRoot = $dir }
                }
            }
        }
        Get-ChildItem -LiteralPath $srcRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    $probe = Join-Path $target $ProbeRelative
    if (Test-Path -LiteralPath $probe) { return 0 }
    # vkd3d 用 x86；再试一遍探测
    $any = Get-OrChildFiles -Path $target -Filter $probeName -Recurse | Select-Object -First 1
    if ($any) { return 0 }
    return -1
}

function Install-OrDxvkPackage {
    param(
        [string]$ZipPath,
        [scriptblock]$Progress = $null
    )
    return (Install-OrZipToGfxDir -ZipPath $ZipPath -TargetName 'DXVK' -ProbeRelative 'x64\d3d11.dll' `
            -ProgressText '正在解压 DXVK 1.10.3（把 D3D9/10/11 转到 Vulkan，勿改 System32）...' -Progress $Progress)
}

function Install-OrVkd3dPackage {
    param(
        [string]$ZipPath,
        [scriptblock]$Progress = $null
    )
    return (Install-OrZipToGfxDir -ZipPath $ZipPath -TargetName 'vkd3d' -ProbeRelative 'x64\d3d12.dll' `
            -ProgressText '正在解压 vkd3d-proton 2.6（把 D3D12 转到 Vulkan）...' -Progress $Progress)
}

function Get-OrGfxArchFolder {
    param([bool]$Is64)
    if ($Is64) { return 'x64' }
    return 'x32'
}

function Deploy-OrGfxDllsToDir {
    # 把 DXVK / vkd3d 的 DLL 拷到程序目录（绝不写 System32）
    param(
        [string]$AppDir,
        [bool]$Is64,
        [scriptblock]$Progress = $null
    )
    $copied = @()
    $dx = Get-OrDxvkDir
    if ($dx) {
        $arch = Get-OrGfxArchFolder -Is64 $Is64
        $src = Join-Path $dx $arch
        if (-not (Test-Path -LiteralPath $src)) {
            if (-not $Is64) { $src = Join-Path $dx 'x86' }
        }
        if (Test-Path -LiteralPath $src) {
            foreach ($n in @('d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll')) {
                $f = Join-Path $src $n
                if (-not (Test-Path -LiteralPath $f)) { continue }
                Copy-Item -LiteralPath $f -Destination (Join-Path $AppDir $n) -Force -ErrorAction SilentlyContinue
                $copied += $n
            }
        }
    }
    $vk = Get-OrVkd3dDir
    if ($vk) {
        $arch = 'x64'
        if (-not $Is64) { $arch = 'x86' }
        $src = Join-Path $vk $arch
        if (-not (Test-Path -LiteralPath $src) -and -not $Is64) { $src = Join-Path $vk 'x32' }
        if (Test-Path -LiteralPath $src) {
            foreach ($n in @('d3d12.dll', 'd3d12core.dll')) {
                $f = Join-Path $src $n
                if (-not (Test-Path -LiteralPath $f)) { continue }
                Copy-Item -LiteralPath $f -Destination (Join-Path $AppDir $n) -Force -ErrorAction SilentlyContinue
                $copied += $n
            }
        }
    }
    if ($copied.Count -gt 0 -and $Progress) {
        & $Progress '正在放入兼容文件…'
    }
    return , $copied
}

function Get-OrDgVoodooDir {
    $d = Join-Path (Get-OrGfxRoot) 'dgVoodoo2'
    if (Test-Path -LiteralPath (Join-Path $d 'MS\x86\D3D9.dll')) { return $d }
    if (Test-Path -LiteralPath (Join-Path $d 'MS\x86\D3D8.dll')) { return $d }
    if (Test-Path -LiteralPath (Join-Path $d 'x86\D3D9.dll')) { return $d }
    return $null
}

function Test-OrDgVoodooInstalled {
    return [bool](Get-OrDgVoodooDir)
}

function Install-OrDgVoodooPackage {
    param(
        [string]$ZipPath,
        [scriptblock]$Progress = $null
    )
    return (Install-OrZipToGfxDir -ZipPath $ZipPath -TargetName 'dgVoodoo2' -ProbeRelative 'MS\x86\D3D9.dll' `
            -ProgressText '正在准备老游戏图形兼容（dgVoodoo2）...' -Progress $Progress)
}

function Deploy-OrDgVoodooToDir {
    # 过山车大亨 / 遥远的世界等 Win7 老游戏在 Win10 闪退时，把 dgVoodoo DLL 放进游戏目录
    param(
        [string]$AppDir,
        [bool]$Is64,
        [scriptblock]$Progress = $null
    )
    $root = Get-OrDgVoodooDir
    if (-not $root) { return , @() }
    $arch = 'x86'
    if ($Is64) { $arch = 'x64' }
    $src = Join-Path $root ('MS\' + $arch)
    if (-not (Test-Path -LiteralPath $src)) { $src = Join-Path $root $arch }
    if (-not (Test-Path -LiteralPath $src)) { $src = Join-Path $root 'MS\x86' }
    if (-not (Test-Path -LiteralPath $src)) { $src = Join-Path $root 'x86' }
    $copied = @()
    if (Test-Path -LiteralPath $src) {
        foreach ($n in @('D3D8.dll', 'D3D9.dll', 'DDraw.dll', 'D3DImm.dll')) {
            $f = Join-Path $src $n
            if (-not (Test-Path -LiteralPath $f)) { continue }
            Copy-Item -LiteralPath $f -Destination (Join-Path $AppDir $n) -Force -ErrorAction SilentlyContinue
            $copied += $n
        }
    }
    foreach ($n in @('dgVoodoo.conf', 'd3drm.dll')) {
        $f = Join-Path $root $n
        if (-not (Test-Path -LiteralPath $f)) { continue }
        Copy-Item -LiteralPath $f -Destination (Join-Path $AppDir $n) -Force -ErrorAction SilentlyContinue
        $copied += $n
    }
    if ($copied.Count -gt 0 -and $Progress) { & $Progress '正在放入老游戏兼容文件…' }
    return , $copied
}

function Set-OrExeCompatLayer {
    # 给 exe 打上「用 Windows 7 兼容」等标记（和右键属性→兼容性一样，但自动完成）
    param(
        [string]$ExePath,
        [string]$Flags = '~ WIN7RTM HIGHDPIAWARE'
    )
    $ok = $false
    $paths = @(
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
    )
    foreach ($p in $paths) {
        try {
            if (-not (Test-Path -LiteralPath $p)) {
                New-Item -Path $p -Force | Out-Null
            }
            New-ItemProperty -LiteralPath $p -Name $ExePath -Value $Flags -PropertyType String -Force -ErrorAction Stop | Out-Null
            $ok = $true
        }
        catch { }
    }
    return $ok
}

function Enable-OrDirectPlay {
    # 部分老游戏（含过山车大亨联机）需要 DirectPlay；Win10 默认没开
    param([scriptblock]$Progress = $null)
    $dism = Get-OrSystemExe 'dism.exe'
    if (-not $dism) { return -1 }
    try {
        $info = & $dism /Online /Get-FeatureInfo /FeatureName:DirectPlay 2>$null | Out-String
        if ($info -match 'State\s*:\s*(Enabled|Enable Pending|已启用|启用待定)') { return 0 }
    }
    catch { }
    if ($Progress) { & $Progress '正在开启老游戏网络组件 DirectPlay…' }
    try {
        return (Start-OrExeWait -FilePath $dism -Arguments '/Online /Enable-Feature /FeatureName:DirectPlay /All /NoRestart' -Progress $Progress -ProgressText '开启 DirectPlay' -TimeoutSec 600)
    }
    catch { return -1 }
}

function Get-VxKexInstallDir {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'VxKex'),
        'C:\Program Files\VxKex',
        'C:\Program Files (x86)\VxKex'
    )
    foreach ($c in $candidates) {
        if (-not (Test-Path -LiteralPath $c)) { continue }
        if (Test-Path -LiteralPath (Join-Path $c 'KexDll.dll')) { return $c }
        $any = Get-ChildItem -LiteralPath $c -Filter 'Kex*.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($any) { return $c }
        if (Test-Path -LiteralPath (Join-Path $c 'Core')) { return $c }
    }
    return $null
}

function Test-VxKexInstalled {
    if (Get-VxKexInstallDir) { return $true }
    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\VxKex') { return $true }
    $u = Get-UninstallEntries
    foreach ($e in $u) {
        if ($e.DisplayName -match 'VxKex') { return $true }
    }
    return $false
}

function Get-LocaleEmulatorDir {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'LocaleEmulator'),
        (Join-Path $env:ProgramFiles 'Locale Emulator'),
        (Join-Path $env:SystemDrive 'LocaleEmulator')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $c 'LEProc.exe')) { return $c }
    }
    return $null
}

function Test-LocaleEmulatorInstalled {
    if (Get-LocaleEmulatorDir) { return $true }
    try {
        $hit = Get-ChildItem -Path (Join-Path $env:ProgramFiles '*') -Filter 'LEProc.exe' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($hit) { return $true }
    }
    catch { }
    return $false
}

function Send-EnterToMatchingWindows {
    param([string[]]$TitleParts)
    try {
        $wshell = New-Object -ComObject WScript.Shell
        foreach ($part in $TitleParts) {
            if ($wshell.AppActivate($part)) {
                Start-Sleep -Milliseconds 200
                $wshell.SendKeys('{ENTER}')
                Start-Sleep -Milliseconds 200
            }
        }
    }
    catch { }
}

function Install-VxKexPackage {
    param(
        [string]$SetupPath,
        [scriptblock]$Progress = $null
    )
    if (-not (Test-Path -LiteralPath $SetupPath)) {
        throw '找不到 KexSetup 安装包'
    }
    $dir = Join-Path $env:ProgramFiles 'VxKex'
    if ($Progress) { & $Progress '正在静默安装 VxKex（让 Win7 能跑较新软件）...' }
    $argSets = @(
        ('/SILENTUNATTEND /KEXDIR:"{0}"' -f $dir),
        ('/VERYSILENT /NORESTART /KEXDIR="{0}"' -f $dir),
        ('/SILENT /KEXDIR:"{0}"' -f $dir),
        '/SILENTUNATTEND',
        '/VERYSILENT /NORESTART',
        ''
    )
    $code = -1
    foreach ($arg in $argSets) {
        try {
            if ($Progress) { & $Progress ('VxKex 尝试参数: ' + $arg) }
            $code = Start-OrProcess -FilePath $SetupPath -Arguments $arg -Progress $Progress -ProgressText '正在安装 VxKex' -TimeoutSec 900
            if (Test-VxKexInstalled) { return 0 }
            if ($code -eq 0 -or $code -eq 3010) { break }
        }
        catch { $code = -1 }
    }
    if (Test-VxKexInstalled) { return 0 }
    return $code
}

function Install-LocaleEmulatorPackage {
    param(
        [string]$ZipPath,
        [scriptblock]$Progress = $null
    )
    if (-not (Test-Path -LiteralPath $ZipPath)) {
        throw '找不到 Locale Emulator 压缩包'
    }

    $target = Join-Path $env:ProgramFiles 'LocaleEmulator'
    if ($Progress) { & $Progress '正在解压 Locale Emulator（解决日文软件乱码）...' }

    if (Test-Path -LiteralPath $target) {
        # Keep folder if already present; still re-register
    }
    else {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }

    $tmp = Join-Path $env:TEMP ('LE_extract_' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    try { New-Item -ItemType Directory -Path $tmp -Force | Out-Null } catch { }
    try {
        Expand-OrArchive -ZipPath $ZipPath -Destination $tmp -Progress $Progress | Out-Null
    }
    catch {
        throw ("Locale Emulator 解压失败: " + $_.Exception.Message)
    }

    $srcRoot = $tmp
    $foundProc = Get-OrChildFiles -Path $tmp -Filter 'LEProc.exe' -Recurse | Select-Object -First 1
    if ($foundProc) { $srcRoot = $foundProc.DirectoryName }

    $children = Get-OrChildFiles -Path $srcRoot
    # also dirs
    try {
        Get-ChildItem -LiteralPath $srcRoot -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $destItem = Join-Path $target $_.Name
            if (Test-Path -LiteralPath $destItem) {
                Remove-Item -LiteralPath $destItem -Recurse -Force -ErrorAction SilentlyContinue
            }
            Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        foreach ($f in $children) {
            Copy-Item -LiteralPath $f.FullName -Destination $target -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue

    $installer = Join-Path $target 'LEInstaller.exe'
    if (-not (Test-Path -LiteralPath $installer)) {
        throw '解压后未找到 LEInstaller.exe'
    }

    # LE 默认就会用日语环境；装好后右键即可「用日语运行」
    if ($Progress) { & $Progress '正在注册右键菜单（完成后会自动点确定）...' }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $installer
    $psi.Arguments = '--InstallAll'
    $psi.WorkingDirectory = $target
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $false
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    $start = Get-Date
    while (-not $proc.HasExited) {
        $elapsed = [int]((Get-Date) - $start).TotalSeconds
        if ($Progress) { & $Progress ("注册 Locale Emulator… {0}s（自动确认弹窗中）" -f $elapsed) }
        Send-EnterToMatchingWindows -TitleParts @('Locale Emulator', 'LE Context Menu', 'Install finished', 'LEInstaller')
        try { [System.Windows.Forms.Application]::DoEvents() } catch { }
        Start-Sleep -Milliseconds 300
        if ($elapsed -gt 180) {
            try { $proc.Kill() } catch { }
            break
        }
    }
    Start-Sleep -Milliseconds 500
    Send-EnterToMatchingWindows -TitleParts @('Locale Emulator', 'LE Context Menu', 'Install finished')

    if (Test-Path -LiteralPath (Join-Path $target 'LEProc.exe')) { return 0 }
    return $proc.ExitCode
}
