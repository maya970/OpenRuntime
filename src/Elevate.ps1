param([string]$Target, [string]$Arguments = '')
$ErrorActionPreference = 'Stop'
try {
    if ($Arguments) { Start-Process -FilePath $Target -ArgumentList $Arguments -Verb RunAs | Out-Null }
    else { Start-Process -FilePath $Target -Verb RunAs | Out-Null }
    exit 0
}
catch {
    exit 1
}
