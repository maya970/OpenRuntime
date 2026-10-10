# 如何把 OpenRuntime 上传到 GitHub

## 1. 注册 / 登录

打开 https://github.com 并登录。

## 2. 新建仓库

1. 右上角 **+** → **New repository**
2. Repository name 填：`OpenRuntime`
3. 选 **Public**（方便所有人用）
4. **不要**勾选 “Add a README”（本地已有）
5. 点 **Create repository**

## 3. 推送本地代码

在 `OpenRuntime` 文件夹打开终端（PowerShell 或 Git Bash）：

```powershell
git add .
git status
git commit -m "Initial release: OpenRuntime free runtime installer"
git branch -M main
git remote add origin https://github.com/你的用户名/OpenRuntime.git
git push -u origin main
```

若 GitHub 要登录，按提示用浏览器授权或 Personal Access Token。

## 4. 发一个 Release（推荐，含离线包）

`packages\` 约 460MB，不要把全部二进制推进 git 历史。

1. 运行 `Pack-Release.bat` 生成 `dist\OpenRuntime-offline.zip`
2. 仓库页 → **Releases** → **Create a new release**
3. Tag：`v1.0.0`，把 ZIP 上传为附件
4. 说明：解压后右键 `Install.bat` → 管理员运行（可完全离线）

## 5. 分享

把仓库链接发给朋友即可，例如：

`https://github.com/你的用户名/OpenRuntime`
