# OpenRuntime — 读取 exe/dll 的导入表，找出本机系统 DLL 里不存在的函数（PS 2.0 兼容，只读）

function U16($b, $o) { return [int][BitConverter]::ToUInt16($b, $o) }
function U32($b, $o) { return [long][BitConverter]::ToUInt32($b, $o) }
function CStr($b, $o) {
    if ($o -lt 0 -or $o -ge $b.Length) { return $null }
    $e = $o
    while ($e -lt $b.Length -and $b[$e] -ne 0 -and ($e - $o) -lt 512) { $e++ }
    return [System.Text.Encoding]::ASCII.GetString($b, $o, $e - $o)
}

function Read-OrPe([string]$File, [switch]$WantExports) {
    $r = @{ Ok = $false; File = $File; Err = $null; Machine = 0; Is64 = $false; Imports = @{}; DelayDlls = @(); Exports = $null; OrdMin = 0; OrdMax = -1 }
    try {
        $fi = Get-Item -LiteralPath $File -ErrorAction Stop
        if ($fi.Length -lt 512 -or $fi.Length -gt 419430400) { $r.Err = 'size ' + $fi.Length; return $r }
        $b = [System.IO.File]::ReadAllBytes($File)
    }
    catch { $r.Err = $_.Exception.Message; return $r }

    try {
        if ($b[0] -ne 0x4D -or $b[1] -ne 0x5A) { $r.Err = 'not MZ'; return $r }
        $e = [int](U32 $b 0x3C)
        if ((U32 $b $e) -ne 0x4550) { $r.Err = 'not PE'; return $r }
        $r.Machine = U16 $b ($e + 4)
        $nsec = U16 $b ($e + 6)
        $optSize = U16 $b ($e + 20)
        $opt = $e + 24
        $is64 = ((U16 $b $opt) -eq 0x20B)
        $r.Is64 = $is64
        if ($is64) { $imageBase = [long][BitConverter]::ToUInt64($b, $opt + 24); $dd = $opt + 112 }
        else { $imageBase = U32 $b ($opt + 28); $dd = $opt + 96 }

        $secs = @()
        $so = $opt + $optSize
        for ($i = 0; $i -lt $nsec; $i++) {
            $p = $so + $i * 40
            $secs += , @((U32 $b ($p + 12)), [Math]::Max((U32 $b ($p + 8)), (U32 $b ($p + 16))), (U32 $b ($p + 20)))
        }
        function R2O($rva) {
            foreach ($s in $secs) {
                if ($rva -ge $s[0] -and $rva -lt ($s[0] + $s[1])) { return [int]($rva - $s[0] + $s[2]) }
            }
            return -1
        }
        function Read-Thunks($rva, $vaBase) {
            $list = New-Object System.Collections.ArrayList
            $o = R2O ($rva - $vaBase)
            if ($o -lt 0) { return , $list }
            $sz = 4; if ($is64) { $sz = 8 }
            for ($n = 0; $n -lt 20000; $n++) {
                $p = $o + $n * $sz
                if ($p + $sz -gt $b.Length) { break }
                $lo = U32 $b $p
                $hi = 0; if ($is64) { $hi = U32 $b ($p + 4) }
                if ($lo -eq 0 -and $hi -eq 0) { break }
                if ($b[$p + $sz - 1] -band 0x80) { [void]$list.Add('#' + (U16 $b $p)) }
                else {
                    $no = R2O ($lo - $vaBase)
                    if ($no -ge 0) { [void]$list.Add((CStr $b ($no + 2))) }
                }
            }
            return , $list
        }

        # 导入表（目录 1）
        $impRva = U32 $b ($dd + 8)
        if ($impRva -ne 0) {
            $o = R2O $impRva
            if ($o -ge 0) {
                for ($k = 0; $k -lt 4096; $k++) {
                    $d = $o + $k * 20
                    if ($d + 20 -gt $b.Length) { break }
                    $oft = U32 $b $d; $nameRva = U32 $b ($d + 12); $ft = U32 $b ($d + 16)
                    if ($nameRva -eq 0 -and $ft -eq 0) { break }
                    $dn = CStr $b (R2O $nameRva)
                    if (-not $dn) { continue }
                    $t = $oft; if ($t -eq 0) { $t = $ft }
                    $key = $dn.ToLower()
                    if (-not $r.Imports.ContainsKey($key)) { $r.Imports[$key] = New-Object System.Collections.ArrayList }
                    foreach ($x in (Read-Thunks $t 0)) { [void]$r.Imports[$key].Add($x) }
                }
            }
        }

        # 延迟导入表（目录 13）
        $dlRva = U32 $b ($dd + 104)
        if ($dlRva -ne 0) {
            $o = R2O $dlRva
            if ($o -ge 0) {
                for ($k = 0; $k -lt 1024; $k++) {
                    $d = $o + $k * 32
                    if ($d + 32 -gt $b.Length) { break }
                    $attr = U32 $b $d; $nameRva = U32 $b ($d + 4); $intRva = U32 $b ($d + 16)
                    if ($nameRva -eq 0) { break }
                    $base = 0
                    if ((($attr -band 1) -eq 0) -and -not $is64) { $base = $imageBase }
                    $dn = CStr $b (R2O ($nameRva - $base))
                    if (-not $dn) { continue }
                    $key = $dn.ToLower()
                    $r.DelayDlls += $key
                    if (-not $r.Imports.ContainsKey($key)) { $r.Imports[$key] = New-Object System.Collections.ArrayList }
                    foreach ($x in (Read-Thunks $intRva $base)) { [void]$r.Imports[$key].Add($x) }
                }
            }
        }

        if ($WantExports) {
            $names = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)
            $expRva = U32 $b $dd
            if ($expRva -ne 0) {
                $o = R2O $expRva
                if ($o -ge 0) {
                    $ordBase = U32 $b ($o + 16); $nf = U32 $b ($o + 20); $nn = U32 $b ($o + 24); $an = U32 $b ($o + 32)
                    $ao = R2O $an
                    for ($i = 0; $i -lt $nn; $i++) {
                        $s = CStr $b (R2O (U32 $b ($ao + $i * 4)))
                        if ($s) { $names[$s] = $true }
                    }
                    $r.OrdMin = $ordBase; $r.OrdMax = $ordBase + $nf - 1
                }
            }
            $r.Exports = $names
        }
        $r.Ok = $true
    }
    catch { $r.Err = $_.Exception.Message }
    return $r
}

function Get-OrPeSysDir([bool]$TargetIs64) {
    $osIs64 = ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'AMD64')
    $hostIs64 = ([IntPtr]::Size -eq 8)
    if ($TargetIs64) {
        if ($hostIs64) { return (Join-Path $env:SystemRoot 'System32') }
        return (Join-Path $env:SystemRoot 'Sysnative')
    }
    if ($osIs64 -and $hostIs64) { return (Join-Path $env:SystemRoot 'SysWOW64') }
    return (Join-Path $env:SystemRoot 'System32')
}

$script:OrPeExportCache = @{}
function Get-OrPeExports([string]$DllPath) {
    $k = $DllPath.ToLower()
    if (-not $script:OrPeExportCache.ContainsKey($k)) { $script:OrPeExportCache[$k] = Read-OrPe -File $DllPath -WantExports }
    return $script:OrPeExportCache[$k]
}

function Find-OrMissingImports {
    # 返回：File / Is64 / Dll / Functions（'*' 表示整个 api-ms DLL 不存在）/ Delay
    param([object[]]$Files)
    $results = @()
    foreach ($f in $Files) {
        $pe = Read-OrPe -File $f.FullName
        if (-not $pe.Ok) { continue }
        $sysDir = Get-OrPeSysDir $pe.Is64
        foreach ($dll in @($pe.Imports.Keys)) {
            if ($dll -match '^ext-ms-') { continue }
            $sysPath = Join-Path $sysDir $dll
            $miss = @()
            if (-not (Test-Path -LiteralPath $sysPath)) {
                # Win8+ 由 API Set 架构解析 api-ms-*，不需要实体文件
                if ($dll -match '^api-ms-' -and [Environment]::OSVersion.Version -lt (New-Object Version 6, 2) -and
                    -not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $f.FullName) $dll)) -and
                    -not (Test-Path -LiteralPath (Join-Path (Join-Path $sysDir 'downlevel') $dll))) { $miss = @('*') }
            }
            else {
                $ex = Get-OrPeExports $sysPath
                if (-not $ex.Ok -or -not $ex.Exports) { continue }
                foreach ($fn in $pe.Imports[$dll]) {
                    if (-not $fn) { continue }
                    if ($fn.StartsWith('#')) {
                        $ord = [int]$fn.Substring(1)
                        if ($ord -lt $ex.OrdMin -or $ord -gt $ex.OrdMax) { $miss += $fn }
                    }
                    elseif (-not $ex.Exports.ContainsKey($fn)) { $miss += $fn }
                }
            }
            if ($miss.Count -gt 0) {
                $results += (New-Object PSObject -Property @{
                        File = $f.FullName; Is64 = $pe.Is64; Dll = $dll; Functions = $miss; Delay = ($pe.DelayDlls -contains $dll)
                    })
            }
        }
    }
    return , $results
}
