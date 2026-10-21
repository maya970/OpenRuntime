# OpenRuntime — runtime catalog (Microsoft official download URLs only)
# Compatible with Windows PowerShell 2.0+

function Get-OpenRuntimeCatalog {
    <#
    .SYNOPSIS
        Returns the list of redistributable packages OpenRuntime can install.
    #>
    $is64 = $false
    if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'AMD64') {
        $is64 = $true
    }
    elseif ([Environment]::Is64BitOperatingSystem) {
        $is64 = $true
    }
    $os = [Environment]::OSVersion.Version
    # Windows 10 = 10.0; Windows 7 = 6.1; Windows 8.1 = 6.3
    $isWin7Or81 = ($os.Major -lt 10)

    # VC++ 2015+: Win10+ uses latest; Win7/8.1 uses pinned 14.29 (offline filenames differ).
    if ($isWin7Or81) {
        $vc14x86 = 'https://aka.ms/vs/16/release/14.29.30157/VC_Redist.x86.exe'
        $vc14x64 = 'https://aka.ms/vs/16/release/14.29.30157/VC_Redist.x64.exe'
        $vc14FileX86 = 'vc_redist_x86_win7.exe'
        $vc14FileX64 = 'vc_redist_x64_win7.exe'
        $vc14Note = 'Offline 14.29.30157 (Win7 SP1)'
    }
    else {
        $vc14x86 = 'https://aka.ms/vc14/vc_redist.x86.exe'
        $vc14x64 = 'https://aka.ms/vc14/vc_redist.x64.exe'
        $vc14FileX86 = 'vc_redist_x86.exe'
        $vc14FileX64 = 'vc_redist_x64.exe'
        $vc14Note = 'Offline latest VC++ 2015–2022+'
    }

    $list = @(
        @{
            Id          = 'vc2005_x86'
            Name        = 'Visual C++ 2005 SP1 MFC (x86)'
            Arch        = 'x86'
            Category    = 'VC++'
            # KB2538242 / download id 26347 — note path ends with ...FD8D66A (old FD7D696 is 404)
            Url         = 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE'
            FileName    = 'vcredist_2005_x86.exe'
            Args        = '/Q'
            Detect      = @{
                Kind    = 'ProductCode'
                Codes   = @('{710f4c1c-cc18-4c49-8cbf-51240c89a1a2}', '{710f4c1c-cc18-4c99-88df-27216de68369}')
                Pattern = 'Microsoft Visual C\+\+ 2005 Redistributable(?! \(x64\))'
            }
            Enabled     = $true
            Note        = 'MFC Security Update'
        },
        @{
            Id          = 'vc2008_x86'
            Name        = 'Visual C++ 2008 SP1 (x86)'
            Arch        = 'x86'
            Category    = 'VC++'
            Url         = 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe'
            FileName    = 'vcredist_2008_x86.exe'
            Args        = '/q'
            Detect      = @{ Kind = 'UninstallName'; Pattern = 'Microsoft Visual C\+\+ 2008.*Redistributable.*x86' }
            Enabled     = $true
            Note        = ''
        },
        @{
            Id          = 'vc2010_x86'
            Name        = 'Visual C++ 2010 SP1 (x86)'
            Arch        = 'x86'
            Category    = 'VC++'
            Url         = 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe'
            FileName    = 'vcredist_2010_x86.exe'
            Args        = '/q /norestart'
            Detect      = @{ Kind = 'UninstallName'; Pattern = 'Microsoft Visual C\+\+ 2010.*Redistributable.*x86' }
            Enabled     = $true
            Note        = ''
        },
        @{
            Id          = 'vc2012_x86'
            Name        = 'Visual C++ 2012 Update 4 (x86)'
            Arch        = 'x86'
            Category    = 'VC++'
            Url         = 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe'
            FileName    = 'vcredist_2012_x86.exe'
            Args        = '/install /quiet /norestart'
            Detect      = @{ Kind = 'UninstallName'; Pattern = 'Microsoft Visual C\+\+ 2012 Redistributable \(x86\)' }
            Enabled     = $true
            Note        = ''
        },
        @{
            Id          = 'vc2013_x86'
            Name        = 'Visual C++ 2013 (x86)'
            Arch        = 'x86'
            Category    = 'VC++'
            Url         = 'https://aka.ms/highdpimfc2013x86enu'
            FileName    = 'vcredist_2013_x86.exe'
            Args        = '/install /quiet /norestart'
            Detect      = @{ Kind = 'UninstallName'; Pattern = 'Microsoft Visual C\+\+ 2013 Redistributable \(x86\)' }
            Enabled     = $true
            Note        = ''
        },
        @{
            Id          = 'vc14_x86'
            Name        = 'Visual C++ 2015–2022 (x86)'
            Arch        = 'x86'
            Category    = 'VC++'
            Url         = $vc14x86
            FileName    = $vc14FileX86
            Args        = '/install /quiet /norestart'
            Detect      = @{ Kind = 'VcRuntime'; Arch = 'x86'; MinMajor = 14 }
            Enabled     = $true
            Note        = $vc14Note
        }
    )

    if ($is64) {
        $list += @(
            @{
                Id          = 'vc2005_x64'
                Name        = 'Visual C++ 2005 SP1 MFC (x64)'
                Arch        = 'x64'
                Category    = 'VC++'
                Url         = 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.EXE'
                FileName    = 'vcredist_2005_x64.exe'
                Args        = '/Q'
                Detect      = @{
                    Kind    = 'ProductCode'
                    Codes   = @('{ad8a2fa1-06e7-4b0d-927d-6e54b3d31028}', '{AD8A2FA1-06E7-4B0D-927D-6E54B3D31028}')
                    Pattern = 'Microsoft Visual C\+\+ 2005 Redistributable \(x64\)'
                }
                Enabled     = $true
                Note        = 'MFC Security Update'
            },
            @{
                Id          = 'vc2008_x64'
                Name        = 'Visual C++ 2008 SP1 (x64)'
                Arch        = 'x64'
                Category    = 'VC++'
                Url         = 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe'
                FileName    = 'vcredist_2008_x64.exe'
                Args        = '/q'
                Detect      = @{ Kind = 'UninstallName'; Pattern = 'Microsoft Visual C\+\+ 2008.*Redistributable.*x64' }
                Enabled     = $true
                Note        = ''
            },
            @{
                Id          = 'vc2010_x64'
                Name        = 'Visual C++ 2010 SP1 (x64)'
                Arch        = 'x64'
                Category    = 'VC++'
                Url         = 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe'
                FileName    = 'vcredist_2010_x64.exe'
                Args        = '/q /norestart'
                Detect      = @{ Kind = 'UninstallName'; Pattern = 'Microsoft Visual C\+\+ 2010.*Redistributable.*x64' }
                Enabled     = $true
                Note        = ''
            },
            @{
                Id          = 'vc2012_x64'
                Name        = 'Visual C++ 2012 Update 4 (x64)'
                Arch        = 'x64'
                Category    = 'VC++'
                Url         = 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe'
                FileName    = 'vcredist_2012_x64.exe'
                Args        = '/install /quiet /norestart'
                Detect      = @{ Kind = 'UninstallName'; Pattern = 'Microsoft Visual C\+\+ 2012 Redistributable \(x64\)' }
                Enabled     = $true
                Note        = ''
            },
            @{
                Id          = 'vc2013_x64'
                Name        = 'Visual C++ 2013 (x64)'
                Arch        = 'x64'
                Category    = 'VC++'
                Url         = 'https://aka.ms/highdpimfc2013x64enu'
                FileName    = 'vcredist_2013_x64.exe'
                Args        = '/install /quiet /norestart'
                Detect      = @{ Kind = 'UninstallName'; Pattern = 'Microsoft Visual C\+\+ 2013 Redistributable \(x64\)' }
                Enabled     = $true
                Note        = ''
            },
            @{
                Id          = 'vc14_x64'
                Name        = 'Visual C++ 2015–2022 (x64)'
                Arch        = 'x64'
                Category    = 'VC++'
                Url         = $vc14x64
                FileName    = $vc14FileX64
                Args        = '/install /quiet /norestart'
                Detect      = @{ Kind = 'VcRuntime'; Arch = 'x64'; MinMajor = 14 }
                Enabled     = $true
                Note        = $vc14Note
            }
        )
    }

    # .NET Framework 4.8 — offline full installer (bundled in packages\)
    $list += @{
        Id          = 'dotnet48'
        Name        = '.NET Framework 4.8'
        Arch        = 'any'
        Category    = '.NET'
        Url         = 'https://go.microsoft.com/fwlink/?linkid=2088631'
        FileName    = 'ndp48-x86-x64-AllOS-ENU.exe'
        Args        = '/q /norestart'
        Detect      = @{ Kind = 'DotNet48' }
        Enabled     = $true
        Note        = 'Offline full installer'
    }

    # PowerShell 5.1 via WMF 5.1 — Win7/8.1 only (Win10+ already ships 5.1+)
    # Prefer pre-extracted .msu from packages\ (no network / no zip step).
    $needWmf = $false
    $ps = $PSVersionTable.PSVersion
    if ($ps.Major -lt 5 -or ($ps.Major -eq 5 -and $ps.Minor -lt 1)) {
        $needWmf = $true
    }
    if ($os.Major -ge 10) {
        $needWmf = $false
    }

    if ($needWmf -and $os.Major -eq 6 -and $os.Minor -eq 1) {
        if ($is64) {
            $wmfFile = 'Win7AndW2K8R2-KB3191566-x64.msu'
            $wmfUrl = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7AndW2K8R2-KB3191566-x64.zip'
        }
        else {
            $wmfFile = 'Win7-KB3191566-x86.msu'
            $wmfUrl = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7-KB3191566-x86.zip'
        }
        $list += @{
            Id          = 'wmf51'
            Name        = 'Windows PowerShell 5.1 (WMF 5.1)'
            Arch        = 'any'
            Category    = 'PowerShell'
            Url         = $wmfUrl
            FileName    = $wmfFile
            Args        = '/quiet /norestart'
            Detect      = @{ Kind = 'PowerShell51' }
            Enabled     = $true
            Note        = '多CAB按序安装; 装完需重启'
            Special     = 'Msu'
        }
    }
    elseif ($needWmf -and $os.Major -eq 6 -and $os.Minor -ge 3) {
        $list += @{
            Id          = 'wmf51'
            Name        = 'Windows PowerShell 5.1 (WMF 5.1)'
            Arch        = 'any'
            Category    = 'PowerShell'
            Url         = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win8.1AndW2K12R2-KB3191564-x64.msu'
            FileName    = 'Win8.1AndW2K12R2-KB3191564-x64.msu'
            Args        = '/quiet /norestart'
            Detect      = @{ Kind = 'PowerShell51' }
            Enabled     = $is64
            Note        = '多CAB按序安装; 装完需重启'
            Special     = 'Msu'
        }
    }

    # DirectX End-User Runtime (June 2010) — still needed by many older games
    $list += @{
        Id          = 'directx_jun2010'
        Name        = 'DirectX End-User Runtime (Jun 2010)'
        Arch        = 'any'
        Category    = 'DirectX'
        Url         = 'https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe'
        FileName    = 'directx_Jun2010_redist.exe'
        Args        = '/Q'
        Detect      = @{ Kind = 'DirectXJun2010' }
        Enabled     = $true
        Note        = 'Extract + DXSETUP; optional for modern OS'
        Special     = 'DirectXCab'
    }

    # Locale Emulator — Japanese / special codepage apps (called「字体/区域」by many users)
    $list += @{
        Id          = 'locale_emulator'
        Name        = 'Locale Emulator（日文软件乱码修复）'
        Arch        = 'any'
        Category    = '区域字体'
        Url         = ''
        FileName    = 'Locale.Emulator.2.5.0.1.zip'
        Args        = ''
        Detect      = @{ Kind = 'LocaleEmulator' }
        Enabled     = $true
        Note        = '装好后：右键程序 → Locale Emulator'
        Special     = 'LocaleEmulator'
    }

    # VxKex — Win7 only API extension for newer apps
    if ($os.Major -eq 6 -and $os.Minor -eq 1) {
        $list += @{
            Id          = 'vxkex'
            Name        = 'VxKex（Win7 运行新版软件扩展）'
            Arch        = 'any'
            Category    = '兼容'
            Url         = ''
            FileName    = 'KexSetup_Release_1_2_3_2463.exe'
            Args        = ''
            Detect      = @{ Kind = 'VxKex' }
            Enabled     = $true
            Note        = '打不开时只点「一键修复打不开的程序」'
            Special     = 'VxKex'
        }

        # 图形兼容层：不出现在列表里，避免小白多点。由「一键修复」静默装齐并拷到程序旁。
        $list += @{
            Id          = 'vulkan_rt'
            Name        = 'Vulkan Runtime 1.2.198.1（Win7）'
            Arch        = 'any'
            Category    = '图形'
            Url         = 'https://web.archive.org/web/20211231143401id_/https://sdk.lunarg.com/sdk/download/1.2.198.1/windows/VulkanRT-1.2.198.1-Installer.exe'
            FileName    = 'VulkanRT-1.2.198.1-Installer.exe'
            Args        = '/S'
            Detect      = @{ Kind = 'VulkanRuntime' }
            Enabled     = $false
            Note        = '由一键修复自动安装'
            Special     = 'VulkanRuntime'
        }
        $list += @{
            Id          = 'dxvk'
            Name        = 'DXVK 1.10.3（D3D9/11→Vulkan）'
            Arch        = 'any'
            Category    = '图形'
            Url         = ''
            FileName    = 'dxvk-1.10.3.zip'
            Args        = ''
            Detect      = @{ Kind = 'Dxvk' }
            Enabled     = $false
            Note        = '由一键修复自动安装'
            Special     = 'Dxvk'
        }
        $list += @{
            Id          = 'vkd3d'
            Name        = 'vkd3d-proton 2.6（D3D12→Vulkan）'
            Arch        = 'any'
            Category    = '图形'
            Url         = ''
            FileName    = 'vkd3d-proton-2.6.zip'
            Args        = ''
            Detect      = @{ Kind = 'Vkd3d' }
            Enabled     = $false
            Note        = '由一键修复自动安装'
            Special     = 'Vkd3d'
        }
    }

    # Win10/11：老 Win7 游戏闪退（过山车大亨、遥远的世界等）——不进列表，由一键修复静默处理
    if ($os.Major -ge 10) {
        $list += @{
            Id          = 'dgvoodoo2'
            Name        = 'dgVoodoo2（老游戏图形兼容）'
            Arch        = 'any'
            Category    = '图形'
            Url         = 'https://github.com/dege-diosg/dgVoodoo2/releases/download/v2.87.5/dgVoodoo2_87_5.zip'
            FileName    = 'dgVoodoo2_87_5.zip'
            Args        = ''
            Detect      = @{ Kind = 'DgVoodoo' }
            Enabled     = $false
            Note        = '由一键修复自动安装'
            Special     = 'DgVoodoo'
        }
    }

    return $list
}
