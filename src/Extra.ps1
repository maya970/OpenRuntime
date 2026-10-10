# OpenRuntime — VxKex + Locale Emulator (auto for Chinese beginners)
# Compatible with Windows PowerShell 2.0+

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
