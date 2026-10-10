Clash / Mihomo Party 在 Win7 报错：
  应用初始化失败
  TypeError: Promise.withResolvers is not a function

这不是缺 VC++，而是程序 JS 用了新 API，旧 Electron 没有。

【推荐】换官方已修 Win7 包（文件名必须带 win7）
  https://github.com/mihomo-party-org/clash-party/releases/tag/v1.9.4
  下载：clash-party-win7-1.9.4-x64-setup.exe
     或：clash-party-win7-1.9.4-x64-portable.7z
  不要下没有 “win7” 字样的普通版。

【仍报错时】用本目录 polyfill 启动
  1. 把 Start-WithPromisePolyfill.bat
     和 promise-withresolvers-polyfill.js
     拷到 Clash 安装目录（和 exe 同级）
  2. 双击 Start-WithPromisePolyfill.bat 启动
     （不要再直接双击原来的 exe）

【还不行】
  - 确认已重启且 PowerShell 已是 5.1（OpenRuntime 装 WMF 后）
  - 试更旧可用包：1.8.9 的 win7/portable
  - 安装目录路径不要有空格（如放到 E:\ClashParty\）
  - OpenRuntime 装齐 VC++ 后仍不够单独解决此 Promise 错误
