OpenRuntime offline packages
============================

This folder contains official Microsoft redistributables and curated Win7
compatibility extras. OpenRuntime installs from here FIRST — no internet required.

Included:
- Visual C++ 2005 / 2008 / 2010 / 2012 / 2013 (x86 + x64)
- Visual C++ 2015-2022 latest (x86 + x64) + Win7-compatible 14.29 builds
- .NET Framework 4.8 offline installer
- DirectX End-User Runtime (June 2010)
- PowerShell 5.1 / WMF 5.1 MSU (Win7 x86/x64, Win8.1 x64)
- Locale Emulator + VxKex (Win7)
- Vulkan Runtime 1.2.198.1 (last LunarG RT known to work on Win7)
- DXVK 1.10.3 (D3D9/10/11 -> Vulkan; app-folder DLLs only, never System32)
- vkd3d-proton 2.6 (D3D12 -> Vulkan; app-folder DLLs; needs Vulkan)
- dgVoodoo2 (Win10/11: old Win7-era games that crash on launch; app-folder DLLs)

Do not rename these files. See MANIFEST.txt for sizes.

Author: maya970
https://github.com/maya970
