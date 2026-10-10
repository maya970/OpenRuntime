# OpenRuntime

**开源、免费、无广告的 Windows 系统运行库一键安装工具**

作者：[maya970](https://github.com/maya970)

自动检测并安装 Visual C++ Redistributable、.NET Framework、DirectX、PowerShell 5.1（WMF）等常用运行库。  
替代当年 3DM / 360 / 驱动精灵一类「运行库合集」——那些现在大多收费或捆绑推广，OpenRuntime 完全开源，安装包只从 **Microsoft 官方地址** 下载。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%207%2B-brightgreen.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-2.0%E2%86%925.1-blue.svg)

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

## 支持的运行库

- Visual C++ **2005 SP1 MFC 安全更新** / 2008 SP1 / 2010 SP1 / 2012 Update 4 / 2013  
- Visual C++ **2015–2022**（Win10+ 用最新；Win7/8.1 锁定 **14.29.30157**）  
- .NET Framework 4.8（Web 安装包）  
- **Windows PowerShell 5.1**（WMF 5.1，Win7/8.1 缺失时自动装；Win10+ 自带则跳过）  
- DirectX End-User Runtime（June 2010，老游戏常用）  
- **Locale Emulator**（日文软件乱码 / 区域设置，自动解压注册右键菜单）  
- **VxKex**（仅 Win7：让较新软件能运行，静默安装）  

## 快速开始

### 普通用户（推荐）

1. 下载本仓库（Code → Download ZIP）或 [Releases](../../releases) 中的压缩包  
2. 解压后 **右键 `Install.bat` → 以管理员身份运行**  
3. 在窗口中点 **「一键安装缺失」**

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
- 完整分发包自带 `packages\`（约 460MB），**可完全离线安装**

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
├── packages/              # 离线官方安装包（见 MANIFEST.txt）
├── tools/curl/            # 仅作联网回退
├── OpenRuntime.ps1
└── src/
```

## 安全说明

- `packages\` 内为 **Microsoft 官方** Redistributable / MSU，未改包。  
- 安装参数使用静默开关（`/quiet /norestart` 等）。  
- 退出码 `3010` = 成功但建议重启；`1638` / `2359302` = 已安装更新版本。  
- 请从本仓库 Release 或你信任的镜像获取完整 ZIP。

## 上传到 GitHub

脚本可用 `git push`；**离线包体积大，请打 Release ZIP 上传附件**，避免把几百 MB 二进制推进 git 历史。

```bash
# 打完整离线包（含 packages）
Compress-Archive -Path .\* -DestinationPath OpenRuntime-offline.zip
```

## 贡献

欢迎提 Issue / PR：补检测规则、更新官方链接、翻译、无障碍改进等。  
修改运行库 URL 时请优先引用 [Microsoft 最新 VC++ 说明](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)。

## 免责声明

OpenRuntime 仅为安装官方 Redistributable 的辅助脚本。运行库版权归 Microsoft 所有。  
使用本工具造成的任何系统问题，作者不承担责任；重要机器请先备份。

## License

[MIT](LICENSE)
