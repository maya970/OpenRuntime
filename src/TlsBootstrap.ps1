# OpenRuntime — enable TLS 1.2 for Windows Schannel (Win7/8.1)
# Safe on Win10+ (idempotent). Requires admin for HKLM writes.

function Enable-OpenRuntimeTls12 {
    <#
    .SYNOPSIS
        Enable TLS 1.2 client/server protocols in Schannel registry (KB3140245-style).
        Also raise .NET ServicePointManager default to include TLS 1.2 (numeric 3072 works on old .NET).
    #>

    $paths = @(
        'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client',
        'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
    )

    foreach ($p in $paths) {
        try {
            if (-not (Test-Path -LiteralPath $p)) {
                New-Item -Path $p -Force | Out-Null
            }
            # Enabled=1, DisabledByDefault=0
            New-ItemProperty -LiteralPath $p -Name 'Enabled' -Value 1 -PropertyType DWord -Force | Out-Null
            New-ItemProperty -LiteralPath $p -Name 'DisabledByDefault' -Value 0 -PropertyType DWord -Force | Out-Null
        }
        catch { }
    }

    # .NET Framework strong-crypto / default TLS (helps WebClient when used)
    $netKeys = @(
        'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319',
        'HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v2.0.50727'
    )
    foreach ($nk in $netKeys) {
        try {
            if (Test-Path -LiteralPath $nk) {
                New-ItemProperty -LiteralPath $nk -Name 'SchUseStrongCrypto' -Value 1 -PropertyType DWord -Force | Out-Null
                New-ItemProperty -LiteralPath $nk -Name 'SystemDefaultTlsVersions' -Value 1 -PropertyType DWord -Force | Out-Null
            }
        }
        catch { }
    }

    # Process-level: TLS1.2 = 3072, TLS1.1 = 768, TLS1.0 = 192
    try {
        $tls12 = 3072
        $current = [int][Net.ServicePointManager]::SecurityProtocol
        [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], ($current -bor $tls12 -bor 768 -bor 192))
    }
    catch {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        }
        catch { }
    }
}
