$ErrorActionPreference = 'SilentlyContinue'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
try {
    . (Join-Path $Root 'src\TlsBootstrap.ps1')
    Enable-OpenRuntimeTls12
}
catch { }
exit 0
