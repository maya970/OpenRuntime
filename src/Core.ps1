# OpenRuntime — detect / download / install
# Compatible with Windows PowerShell 2.0+

$script:OpenRuntimeRoot = $null
$script:UninstallCache = $null

function Set-OpenRuntimeRoot {
    param([string]$Root)
    $script:OpenRuntimeRoot = $Root
}

function New-OrObject {
    param([hashtable]$Properties)
    $o = New-Object PSObject
    foreach ($k in $Properties.Keys) {
        $o | Add-Member -MemberType NoteProperty -Name $k -Value $Properties[$k]
    }
    return $o
}

function Test-ArrayContains {
    param($Array, $Value)
    foreach ($x in @($Array)) {
        if ($x -eq $Value) { return $true }
    }
    return $false
}

function Initialize-OpenRuntimeEnvironment {
    # Enable Schannel TLS 1.2 + .NET strong crypto (admin); also set process SecurityProtocol
    if (Get-Command Enable-OpenRuntimeTls12 -ErrorAction SilentlyContinue) {
        Enable-OpenRuntimeTls12
    }
    else {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        }
        catch { }
    }
}

function Test-IsAdministrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-OpenRuntimeCacheDir {
    $root = Join-Path $env:TEMP 'OpenRuntime'
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return $root
}

function Start-OpenRuntimeProcessPumped {
    param(
        [string]$FilePath,
        [string]$Arguments = '',
        [scriptblock]$Progress = $null,
        [string]$ProgressText = '安装中，请稍候…',
        [int]$TimeoutSec = 3600,
        [string]$WorkDir = $null
    )
    # 多方法轮询见 Robust.ps1 → Start-OrProcess
    return (Start-OrProcess -FilePath $FilePath -Arguments $Arguments -Progress $Progress -ProgressText $ProgressText -TimeoutSec $TimeoutSec -WorkDir $WorkDir)
}

function Get-OpenRuntimeOfflineDir {
    if (-not $script:OpenRuntimeRoot) { return $null }
    $p = Join-Path $script:OpenRuntimeRoot 'packages'
    if (Test-Path -LiteralPath $p) { return $p }
    return $null
}

function Test-OpenRuntimeFileOk {
    param([string]$Path)
    return (Test-OrFileOk -Path $Path -MinSize 1024)
}

function Resolve-OpenRuntimeOfflineFile {
    param([string]$FileName)
    if (-not $FileName) { return $null }

    $dirs = @()
    if ($script:OpenRuntimeRoot) {
        $dirs += (Join-Path $script:OpenRuntimeRoot 'packages')
        $dirs += (Join-Path $script:OpenRuntimeRoot 'assets')
        $dirs += $script:OpenRuntimeRoot
        $parent = Split-Path -Parent $script:OpenRuntimeRoot
        if ($parent) {
            $dirs += $parent
            $dirs += (Join-Path $parent 'packages')
        }
    }
    try { $dirs += (Join-Path (Get-Location).Path 'packages') } catch { }
    try { $dirs += (Join-Path $PSScriptRoot 'packages') } catch { }
    if ($env:TEMP) { $dirs += (Join-Path $env:TEMP 'OpenRuntime') }

    foreach ($dir in $dirs) {
        if (-not (Test-OrPath $dir)) { continue }
        $exact = Join-Path $dir $FileName
        if (Test-OpenRuntimeFileOk $exact) { return $exact }

        $patterns = @($FileName)
        if ($FileName -match 'KexSetup') { $patterns += 'KexSetup*.exe'; $patterns += '*Kex*.exe' }
        if ($FileName -match 'Locale\.Emulator|LocaleEmulator') {
            $patterns += 'Locale.Emulator*.zip'
            $patterns += 'Locale*.zip'
            $patterns += '*Emulator*.zip'
        }
        if ($FileName -match 'banner|index002') { $patterns += 'banner.*'; $patterns += 'index002.*'; $patterns += '*.jpg'; $patterns += '*.png' }
        if ($FileName -match 'vcredist_2005') { $patterns += '*2005*.exe'; $patterns += 'vcredist_x86.EXE'; $patterns += 'vcredist_x64.EXE' }
        if ($FileName -match 'ndp48') { $patterns += 'ndp48*.exe'; $patterns += '*NET*4.8*.exe' }
        if ($FileName -match 'KB3191566') { $patterns += '*KB3191566*.msu'; $patterns += '*KB3191566*.zip' }
        if ($FileName -match 'KB3191564') { $patterns += '*KB3191564*.msu' }
        if ($FileName -match 'directx') { $patterns += '*directx*.exe'; $patterns += '*DirectX*.exe' }

        foreach ($pat in $patterns) {
            $hits = @(Get-OrChildFiles -Path $dir -Filter $pat)
            $hit = $hits | Sort-Object Length -Descending | Select-Object -First 1
            if ($hit -and (Test-OpenRuntimeFileOk $hit.FullName)) {
                return $hit.FullName
            }
        }
    }
    return $null
}

function Test-OpenRuntimeOfflineReady {
    $offline = Get-OpenRuntimeOfflineDir
    if (-not $offline) { return $false }
    $n = @(Get-OrChildFiles -Path $offline).Count
    return ($n -gt 0)
}

function Get-BundledCurlPath {
    if (-not $script:OpenRuntimeRoot) { return $null }
    $candidates = @(
        (Join-Path $script:OpenRuntimeRoot 'tools\curl\curl.exe'),
        (Join-Path $script:OpenRuntimeRoot 'tools\curl\bin\curl.exe')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    # System curl (Win10+)
    $sys = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path -LiteralPath $sys) { return $sys }
    return $null
}

function Get-UninstallEntries {
    if ($script:UninstallCache) { return $script:UninstallCache }

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $entries = @()
    foreach ($p in $paths) {
        try {
            $items = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
            foreach ($it in @($items)) {
                if ($it -and $it.DisplayName) { $entries += $it }
            }
        }
        catch { }
    }
    $script:UninstallCache = $entries
    return $entries
}

function Clear-OpenRuntimeDetectCache {
    $script:UninstallCache = $null
}

function Test-ProductCodeInstalled {
    param(
        [string[]]$Codes,
        [string]$Pattern = $null
    )
    foreach ($code in $Codes) {
        $key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$code"
        $key32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$code"
        if ((Test-Path -LiteralPath $key) -or (Test-Path -LiteralPath $key32)) {
            return $true
        }
        try {
            $installer = New-Object -ComObject WindowsInstaller.Installer
            $products = $installer.Products()
            $want = $code.Trim('{}').ToUpper()
            foreach ($pr in @($products)) {
                if ($pr -eq $want) { return $true }
            }
        }
        catch { }
    }
    if ($Pattern) {
        return Test-UninstallNameInstalled -Pattern $Pattern
    }
    return $false
}

function Test-PowerShell51Installed {
    # 只有系统实际运行的 PowerShell 已是 5.1+ 才算已安装；待重启不算
    return ((Get-OrWmf51State) -eq 'Active')
}

function Expand-OpenRuntimeZip {
    param(
        [string]$ZipPath,
        [string]$Destination,
        [scriptblock]$Progress = $null
    )
    if (Test-OrPath $Destination) {
        try { Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue } catch { }
        try { Remove-Item -Path $Destination -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }
    [void](New-OrDirectory $Destination)
    return (Expand-OrArchive -ZipPath $ZipPath -Destination $Destination -Progress $Progress)
}

function Install-MsuPackage {
    param(
        [string]$MsuPath,
        [scriptblock]$Progress = $null
    )
    # wusa 依赖 Windows Update；服务禁用时用 expand→CAB→DISM（不改服务）
    $code = Install-OrMsu -MsuPath $MsuPath -Progress $Progress
    $okCodes = @(0, 3010, 2359302, 1638)
    $ok = $false
    foreach ($c in $okCodes) { if ($code -eq $c) { $ok = $true; break } }

    if (-not $ok) { return $code }
    if ([System.IO.Path]::GetFileName($MsuPath) -notmatch 'KB319156[4-6]') { return $code }

    # 退出码成功不等于装上了：按系统实际状态复核
    $state = Get-OrWmf51State
    if ($state -eq 'Active') { return $code }
    if ($state -eq 'PendingReboot') {
        if ($Progress) { & $Progress 'KB3191566 已进入系统安装队列，重启电脑后才生效；重启前 PowerShell 仍是旧版本。' }
        return 3010
    }
    if ($Progress) {
        & $Progress '安装程序返回成功，但系统中 KB3191566 不是已安装/待安装状态，PowerShell 5.1 实际没有装上。请查看 %TEMP%\OpenRuntime_DISM_*.log'
    }
    return -1
}

function Install-WmfFromZip {
    param(
        [string]$ZipPath,
        [string]$WorkDir,
        [scriptblock]$Progress = $null
    )
    $extract = Join-Path $WorkDir 'wmf51_extract'
    if ($Progress) { & $Progress '解压 WMF 5.1...' }
    Expand-OpenRuntimeZip -ZipPath $ZipPath -Destination $extract -Progress $Progress

    $msu = Get-OrChildFiles -Path $extract -Filter '*.msu' -Recurse | Select-Object -First 1
    if (-not $msu) {
        throw 'WMF 5.1 ZIP 中未找到 .msu 文件'
    }
    return (Install-MsuPackage -MsuPath $msu.FullName -Progress $Progress)
}

function Test-UninstallNameInstalled {
    param([string]$Pattern)
    $entries = Get-UninstallEntries
    foreach ($e in $entries) {
        if ($e.DisplayName -match $Pattern) { return $true }
    }
    return $false
}

function Test-VcRuntimeInstalled {
    param(
        [string]$Arch,
        [int]$MinMajor = 14
    )
    $paths = @()
    if ($Arch -eq 'x64') {
        $paths += "HKLM:\SOFTWARE\Microsoft\VisualStudio\$MinMajor.0\VC\Runtimes\x64"
        $paths += "HKLM:\SOFTWARE\Microsoft\VisualStudio\$MinMajor.0\VC\Runtimes\X64"
    }
    else {
        $paths += "HKLM:\SOFTWARE\Microsoft\VisualStudio\$MinMajor.0\VC\Runtimes\x86"
        $paths += "HKLM:\SOFTWARE\Microsoft\VisualStudio\$MinMajor.0\VC\Runtimes\X86"
        $paths += "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\$MinMajor.0\VC\Runtimes\x86"
        $paths += "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\$MinMajor.0\VC\Runtimes\X86"
    }

    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p) {
            try {
                $v = Get-ItemProperty -Path $p -ErrorAction Stop
                if ($v.Installed -eq 1 -or $v.Major -ge $MinMajor) { return $true }
            }
            catch { }
        }
    }

    $archLabel = 'x86'
    if ($Arch -eq 'x64') { $archLabel = 'x64' }
    if (Test-UninstallNameInstalled -Pattern "Microsoft Visual C\+\+ 201[5-9].*Redistributable \($archLabel\)") { return $true }
    if (Test-UninstallNameInstalled -Pattern "Microsoft Visual C\+\+ 202[0-9].*Redistributable \($archLabel\)") { return $true }
    return $false
}

function Test-DotNet48Installed {
    $ndp = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
    if (-not (Test-Path -LiteralPath $ndp)) { return $false }
    try {
        $release = (Get-ItemProperty -Path $ndp).Release
        return ($release -ge 528040)
    }
    catch {
        return $false
    }
}

function Test-DirectXJun2010Present {
    $candidates = @(
        (Join-Path $env:windir 'System32\d3dx9_43.dll'),
        (Join-Path $env:windir 'SysWOW64\d3dx9_43.dll')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $true }
    }
    return $false
}

function Test-RuntimeInstalled {
    param([hashtable]$Item)

    $d = $Item.Detect
    switch ($d.Kind) {
        'ProductCode' {
            $pat = $null
            if ($d.ContainsKey('Pattern')) { $pat = $d.Pattern }
            return Test-ProductCodeInstalled -Codes $d.Codes -Pattern $pat
        }
        'UninstallName' { return Test-UninstallNameInstalled -Pattern $d.Pattern }
        'VcRuntime' { return Test-VcRuntimeInstalled -Arch $d.Arch -MinMajor $d.MinMajor }
        'DotNet48' { return Test-DotNet48Installed }
        'DirectXJun2010' { return Test-DirectXJun2010Present }
        'PowerShell51' { return Test-PowerShell51Installed }
        'VxKex' { return Test-VxKexInstalled }
        'LocaleEmulator' { return Test-LocaleEmulatorInstalled }
        default { return $false }
    }
}

function Get-OpenRuntimeStatusList {
    Clear-OpenRuntimeDetectCache
    $catalog = Get-OpenRuntimeCatalog
    $result = @()
    foreach ($item in $catalog) {
        if (-not $item.Enabled) { continue }
        if ($item.Id -eq 'wmf51') {
            $wmfState = Get-OrWmf51State
            $installed = ($wmfState -eq 'Active')
            $statusText = '未安装'
            if ($wmfState -eq 'Active') { $statusText = '已安装' }
            elseif ($wmfState -eq 'PendingReboot') { $statusText = '待重启生效' }
        }
        else {
            $installed = Test-RuntimeInstalled -Item $item
            $statusText = '未安装'
            if ($installed) { $statusText = '已安装' }
        }
        $result += (New-OrObject @{
            Id        = $item.Id
            Name      = $item.Name
            Arch      = $item.Arch
            Category  = $item.Category
            Installed = $installed
            Status    = $statusText
            Note      = $item.Note
            Item      = $item
        })
    }
    return $result
}

function Test-Is64BitOs {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') { return $true }
    if ($env:PROCESSOR_ARCHITEW6432 -eq 'AMD64') { return $true }
    try {
        if ([Environment]::Is64BitOperatingSystem) { return $true }
    }
    catch { }
    return $false
}

function Get-OpenRuntimeSystemInfo {
    $os = Get-WmiObject -Class Win32_OperatingSystem
    $arch = 'x86'
    if (Test-Is64BitOs) { $arch = 'x64' }
    $curl = Get-BundledCurlPath
    $curlOk = $false
    if ($curl) { $curlOk = $true }
    $offlineOk = Test-OpenRuntimeOfflineReady
    return (New-OrObject @{
        Caption      = $os.Caption
        Version      = $os.Version
        Arch         = $arch
        PSVersion    = $PSVersionTable.PSVersion.ToString()
        IsAdmin      = Test-IsAdministrator
        ComputerName = $env:COMPUTERNAME
        HasCurl      = $curlOk
        CurlPath     = $curl
        OfflineReady = $offlineOk
    })
}

function Save-OpenRuntimeFile {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$FileName = $null,
        [scriptblock]$Progress = $null
    )

    $dir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (-not $FileName) {
        $FileName = Split-Path -Leaf $Destination
    }

    # 0) Bundled offline packages\ — never hit the network when present
    $localPath = Resolve-OpenRuntimeOfflineFile -FileName $FileName
    if ($localPath) {
        if ($Progress) { & $Progress '使用本地离线包 packages\ ...' }
        if ((Resolve-Path -LiteralPath $localPath).Path -ne (Join-Path $dir $FileName)) {
            Copy-Item -LiteralPath $localPath -Destination $Destination -Force
        }
        else {
            # Already the offline file itself — Install will use it in place
            if ($Destination -ne $localPath) {
                Copy-Item -LiteralPath $localPath -Destination $Destination -Force
            }
        }
        if ((Test-Path -LiteralPath $Destination) -and ((Get-Item -LiteralPath $Destination).Length -gt 1024)) {
            return
        }
    }

    # 联网回退：curl → BITS → WebClient → certutil → bitsadmin
    try {
        [void](Save-OrDownload -Url $Url -Destination $Destination -Progress $Progress)
    }
    catch {
        throw ("离线包缺失且下载失败: packages\$FileName | " + $_.Exception.Message)
    }

    if (-not (Test-OpenRuntimeFileOk $Destination)) {
        throw ("下载后文件无效: " + $FileName)
    }
}

function Install-DirectXFromCab {
    param(
        [string]$CabExe,
        [string]$WorkDir,
        [scriptblock]$Progress = $null
    )
    $extract = Join-Path $WorkDir 'dx_extract'
    if (Test-Path -LiteralPath $extract) {
        Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $extract -Force | Out-Null

    if ($Progress) { & $Progress '解压 DirectX 运行库...' }
    $code1 = Start-OpenRuntimeProcessPumped -FilePath $CabExe -Arguments "/Q /T:`"$extract`"" -Progress $Progress -ProgressText '解压 DirectX'

    $setup = Join-Path $extract 'DXSETUP.exe'
    if (-not (Test-Path -LiteralPath $setup)) {
        throw 'DXSETUP.exe not found after extracting DirectX redistributable.'
    }

    if ($Progress) { & $Progress '安装 DirectX...' }
    $code2 = Start-OpenRuntimeProcessPumped -FilePath $setup -Arguments '/silent' -Progress $Progress -ProgressText '安装 DirectX'
    return $code2
}

function Install-OpenRuntimeItem {
    param(
        [hashtable]$Item,
        [switch]$Force,
        [scriptblock]$Progress = $null
    )

    if (-not $Force) {
        if (Test-RuntimeInstalled -Item $Item) {
            if ($Progress) { & $Progress ($Item.Name + ' 已安装，跳过') }
            return (New-OrObject @{
                Id = $Item.Id; Name = $Item.Name; Success = $true; Skipped = $true; ExitCode = 0; Message = 'Already installed'
            })
        }
        if ($Item.Id -eq 'wmf51' -and ((Get-OrWmf51State) -eq 'PendingReboot')) {
            if ($Progress) { & $Progress 'PowerShell 5.1 已在待安装队列，需要先重启电脑，重复安装没有用' }
            return (New-OrObject @{
                Id = $Item.Id; Name = $Item.Name; Success = $false; Skipped = $false; ExitCode = 3010; Message = '尚未生效：请重启电脑'
            })
        }
    }

    $cache = Get-OpenRuntimeCacheDir
    $dest = $null

    try {
        # Prefer installing straight from packages\ (no copy / no network)
        $offline = Resolve-OpenRuntimeOfflineFile -FileName $Item.FileName
        if ($offline) {
            $dest = $offline
            if ($Progress) { & $Progress ('找到本地文件：' + $dest) }
        }
        elseif ($Item.Url -and ($Item.Url.Trim().Length -gt 0)) {
            $dest = Join-Path $cache $Item.FileName
            if ($Progress) { & $Progress ('本地没有，正在下载 ' + $Item.Name + '...') }
            Save-OpenRuntimeFile -Url $Item.Url -Destination $dest -FileName $Item.FileName -Progress $Progress
        }
        else {
            throw ("找不到安装文件：{0}`n请确认 packages 文件夹里有此文件（可把文件直接放进 packages）。" -f $Item.FileName)
        }

        if (-not (Test-OpenRuntimeFileOk $dest)) {
            throw ("安装文件无效或太小：{0}" -f $dest)
        }

        if ($Item.Special -eq 'DirectXCab') {
            $code = Install-DirectXFromCab -CabExe $dest -WorkDir $cache -Progress $Progress
        }
        elseif ($Item.Special -eq 'WmfZip') {
            $code = Install-WmfFromZip -ZipPath $dest -WorkDir $cache -Progress $Progress
        }
        elseif ($Item.Special -eq 'Msu') {
            $code = Install-MsuPackage -MsuPath $dest -Progress $Progress
        }
        elseif ($Item.Special -eq 'VxKex') {
            $code = Install-VxKexPackage -SetupPath $dest -Progress $Progress
        }
        elseif ($Item.Special -eq 'LocaleEmulator') {
            $code = Install-LocaleEmulatorPackage -ZipPath $dest -Progress $Progress
        }
        else {
            if ($Progress) { & $Progress ('安装 ' + $Item.Name + '...') }
            $code = Start-OpenRuntimeProcessPumped -FilePath $dest -Arguments $Item.Args -Progress $Progress -ProgressText ('安装 ' + $Item.Name)
        }

        # 0=ok, 1638=newer present, 3010=reboot, 2359302=wusa already installed
        $ok = (Test-ArrayContains -Array @(0, 1638, 3010, 2359302) -Value $code)
        $msg = "Exit code $code"
        if ($code -eq 0) { $msg = 'OK' }
        elseif ($code -eq 1638) { $msg = 'Newer or same version already installed' }
        elseif ($code -eq 3010) { $msg = 'Success (reboot recommended)' }
        elseif ($code -eq 2359302) { $msg = 'Update already installed' }

        return (New-OrObject @{
            Id = $Item.Id; Name = $Item.Name; Success = $ok; Skipped = $false; ExitCode = $code; Message = $msg
        })
    }
    catch {
        return (New-OrObject @{
            Id = $Item.Id; Name = $Item.Name; Success = $false; Skipped = $false; ExitCode = -1; Message = $_.Exception.Message
        })
    }
}

function Install-OpenRuntimeMissing {
    param(
        [switch]$ForceAll,
        [scriptblock]$Progress = $null,
        [scriptblock]$OnItemDone = $null
    )

    $status = Get-OpenRuntimeStatusList
    $targets = @()
    if ($ForceAll) {
        $targets = @($status)
    }
    else {
        foreach ($s in $status) {
            if (-not $s.Installed) { $targets += $s }
        }
    }

    $results = @()
    $i = 0
    $total = @($targets).Count
    foreach ($row in $targets) {
        $i++
        if ($Progress) { & $Progress "[$i/$total] $($row.Name)" }
        $r = Install-OpenRuntimeItem -Item $row.Item -Force:$ForceAll -Progress $Progress
        $results += $r
        if ($OnItemDone) { & $OnItemDone $r }
    }
    Clear-OpenRuntimeDetectCache
    return $results
}
