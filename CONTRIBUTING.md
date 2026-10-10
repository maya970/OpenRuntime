# 贡献指南

感谢你愿意改进 OpenRuntime。

## 原则

1. **只使用 Microsoft 官方下载地址**（`download.microsoft.com`、`aka.ms`、`go.microsoft.com` 等）。
2. **不要**把第三方「合集 EXE」、破解、广告软件打进仓库。
3. 保持 **Windows 7 SP1** 可用：避免仅 Win10+ 的 API；Win7/8.1 上 VC++ 2015+ 使用仍支持的通道。
4. 检测逻辑以注册表 / 卸载项为准，避免误报已安装。

## 改运行库清单

编辑 `src/Runtimes.ps1`：

- 增加条目时写清 `Id`、`Url`、`Args`、`Detect`
- 在 PR 说明里贴上微软文档或下载页链接

## 本地自测

```powershell
# 仅检测
.\OpenRuntime.ps1 -List -NoPause

# 控制台安装缺失（需管理员）
.\OpenRuntime.ps1 -Console -Auto -NoPause
```

在干净虚拟机（Win7 x64、Win10 x64）上各测一遍最理想。

## 提交

- 小改动、说明清楚即可
- 中英文 README 若涉及用户可见行为，请同步更新
