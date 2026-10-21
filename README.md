# OpenRuntime

**开源、免费、无广告的 Windows 系统运行库一键安装工具**

作者：[maya970](https://github.com/maya970)

> ## 版本说明（请先看这里）
>
> | 版本 | 说明 | 下载 |
> |------|------|------|
> | **稳定版 v1.0.0**（推荐日常使用） | 已验证可用的正式版：运行库一键安装、Win7 修复打不开的程序（VxKex）等 | [点此下载稳定版](https://github.com/maya970/OpenRuntime/releases/tag/v1.0.0) |
> | **测试版 v1.1.0-beta**（当前仓库 / 本页对应代码） | 新功能试运行，可能还有问题，欢迎反馈 | [点此下载测试版](https://github.com/maya970/OpenRuntime/releases/tag/v1.1.0-beta) |
>
> **普通用户请优先使用稳定版。** 只有想试用新功能、或愿意帮忙找 bug 时，再下载测试版。
>
> ### 测试版相对稳定版的更新
>
> - **Win7「一键修复」更省事**：选一次 exe 即可，自动装齐 VxKex / Vulkan Runtime / DXVK / vkd3d，并拷到程序旁（列表里不再露出一堆图形项）
> - **Win7 图形兼容**：集成 LunarG VulkanRT 1.2.198.1、DXVK 1.10.3、vkd3d-proton 2.6（把较新的 D3D11/D3D12 需求转到 Vulkan）
> - **Win10/11 老游戏闪退**：同一按钮可修「过山车大亨」「遥远的世界」等 Win7 时代游戏——自动兼容模式（Win7）+ DirectX June 2010 + dgVoodoo2 + DirectPlay
> - 使用说明与弹窗改成小白向：修好后直接双击运行，不用再点别的

自动检测并安装 Visual C++ Redistributable、.NET Framework、DirectX、PowerShell 5.1（WMF）等常用运行库。  
替代当年 3DM / 360 / 驱动精灵一类「运行库合集」——那些现在大多收费或捆绑推广，OpenRuntime 完全开源，安装包只从 **Microsoft 官方地址** 下载。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%207%2B-brightgreen.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-2.0%E2%86%925.1-blue.svg)
![Status](https://img.shields.io/badge/%E5%BD%93%E5%89%8D-v1.1.0--beta%20%E6%B5%8B%E8%AF%95%E7%89%88-orange.svg)

---

## 下载（中文直达）

- **稳定版（推荐）**：[OpenRuntime v1.0.0 Release](https://github.com/maya970/OpenRuntime/releases/tag/v1.0.0) → 下载附件 `OpenRuntime-offline.zip`
- **测试版（本页）**：[OpenRuntime v1.1.0-beta Release](https://github.com/maya970/OpenRuntime/releases/tag/v1.1.0-beta) → 下载附件 `OpenRuntime-offline.zip`
- **全部历史版本**：[Releases 列表](https://github.com/maya970/OpenRuntime/releases)

---

## 特性

| 能力 | 说明 |
|------|------|
| 自动检测 | 扫描注册表 / 卸载项，标出已装与缺失 |
| 一键安装 | GUI 点一下，或控制台静默装全缺失项 |
| 离线安装 | `packages\` 已内置全部官方安装包（约 450MB+），**默认不联网** |
| 官方源 | 缺离线包时才从 `download.microsoft.com` / `aka.ms` 回退下载 |
| Win7 友好 | 自带 curl+LibreSSL + TLS 注册表；脚本兼容 **PowerShell 2.0**；可装 PS 5.1 |
| x86 + x64 | 64 位系统会同时装 32/64 位 VC++（很多软件仍是 32 位） |
| 无捆绑 | 不塞广告、不改主页、不装推广软件 |
| 一键修复 | Win7 跑新软件 / Win10 跑老游戏闪退，同一按钮（测试版增强） |

## 支持的运行库

- Visual C++ **2005 SP1 MFC 安全更新** / 2008 SP1 / 2010 SP1 / 2012 Update 4 / 2013  
- Visual C++ **2015–2022**（Win10+ 用最新；Win7/8.1 锁定 **14.29.30157**）  
- .NET Framework 4.8（Web 安装包）  
- **Windows PowerShell 5.1**（WMF 5.1，Win7/8.1 缺失时自动装；Win10+ 自带则跳过）  
- DirectX End-User Runtime（June 2010，老游戏常用）  
- **Locale Emulator**（日文软件乱码 / 区域设置，自动解压注册右键菜单）  
- **VxKex**（仅 Win7：让较新软件能运行，静默安装）  
- **一键修复打不开的程序**（同一按钮：Win7 用 VxKex/Vulkan/DXVK/vkd3d；Win10 用兼容模式 + DirectX 2010 + dgVoodoo2 + DirectPlay）  

## 快速开始

### 普通用户（推荐）

1. **优先下载 [稳定版 v1.0.0](https://github.com/maya970/OpenRuntime/releases/tag/v1.0.0)**；若要试用新功能再下 [测试版](https://github.com/maya970/OpenRuntime/releases/tag/v1.1.0-beta)  
2. 解压后 **右键 `Install.bat` → 以管理员身份运行**  
3. 在窗口中点 **「一键安装缺失」**  
4. （可选）打不开 / 闪退的程序：点 **「一键修复打不开的程序」**，选出 exe，等做完再双击运行  

### 控制台 / 无人值守

```bat
Install-Console.bat
```

或：

```powershell
# 以管理员打开 PowerShell
Set-ExecutionPolicy -Scope Process Bypass
.\OpenRuntime.ps1 -Console -Auto
```

### 仅检测、不安装

```powershell
.\OpenRuntime.ps1 -List
```

## 系统要求

- Windows **7 SP1** / 8.1 / 10 / 11（含对应 Server）  
- 自带 Windows PowerShell（**2.0 即可**，不必先装 WMF）  
- 安装时需要 **管理员权限**  
- 完整分发包自带 `packages\`（约 460MB+），**可完全离线安装**

### 已集成

| 能力 | 说明 |
|------|------|
| **离线包** | `packages\` 内置 VC++ / .NET 4.8 / DirectX / WMF 5.1 MSU |
| **联网回退** | 仅当某个离线文件缺失时，才用内置 curl 下载 |
| **PS 2.0→5.1** | 脚本可在 PS2 运行；Win7/8.1 可离线装上 PowerShell 5.1 |
| **VC++ 2015+** | Win7 用离线 14.29；Win10+ 用离线最新包 |

## 项目结构

```
OpenRuntime/
├── Install.bat            # 双击入口
├── Fix-Win7App.bat        # 也可把打不开的 exe 拖到这里
├── packages/              # 离线官方安装包（见 MANIFEST.txt）
├── tools/curl/            # 仅作联网回退
├── OpenRuntime.ps1
└── src/
```

## 安全说明

- `packages\` 内为 **Microsoft 官方** Redistributable / MSU，以及标明来源的开源兼容层（DXVK / vkd3d / dgVoodoo2 等），安装脚本未篡改官方安装包。  
- 安装参数使用静默开关（`/quiet /norestart` 等）。  
- 退出码 `3010` = 成功但建议重启；`1638` / `2359302` = 已安装更新版本。  
- 请从本仓库 Release 或你信任的镜像获取完整 ZIP。

## 贡献

欢迎提 Issue / PR：补检测规则、更新官方链接、翻译、无障碍改进等。  
修改运行库 URL 时请优先引用 [Microsoft 最新 VC++ 说明](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)。

## 免责声明

OpenRuntime 仅为安装官方 Redistributable 的辅助脚本。运行库版权归 Microsoft 所有。  
DXVK / vkd3d-proton / dgVoodoo2 / VxKex / Locale Emulator 等版权归各自作者。  
使用本工具造成的任何系统问题，作者不承担责任；重要机器请先备份。

## License

[MIT](LICENSE)
