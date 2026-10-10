# chatgpt-chrome-fix

修复 **ChatGPT 桌面版（Microsoft Store 版）** 与 Chrome 里 **ChatGPT 扩展** 连不上的问题，并注册自动任务，应用更新后自动修复。

适用现象（Chrome 侧栏 Technical details）：

- `Install the app to use ChatGPT in Chrome`
- `Codex Chrome native host v2 manifest is missing`
- `Codex app-server manifest entry is missing required path codexCliPath`
- `No compatible Codex app-server entry was found`

## 前提

1. 已安装 ChatGPT 桌面版（Microsoft Store 版），并且启动过一次、窗口能正常打开
2. Chrome 已安装 ChatGPT 扩展

## 安装（只需一次）

打开 PowerShell，粘贴执行：

```powershell
irm https://raw.githubusercontent.com/Ui6oooooo/chatgpt-chrome-fix/main/install.ps1 | iex
```

看到 `DONE` 后，**完全退出 Chrome 再打开**，在 ChatGPT 侧栏点 **Try again**。

> 如果提示计划任务只注册了 daily（没有 logon），用「管理员 PowerShell」再跑一次同一条命令即可。

## 它做了什么

- 写入 3 个清单文件（Native Messaging 清单、extension-host 配置、`chrome-native-hosts-v2.json`）和 1 个注册表键
- 把清单里的路径对齐到本机当前的应用版本
- 注册计划任务 **Fix ChatGPT Chrome**：登录时 + 每天 09:00 运行一次；每次先从本仓库拉取最新修复脚本再执行（断网时用本地副本）
- 脚本和日志放在 `%LOCALAPPDATA%\chatgpt-chrome-fix\`

## 日常维护

平时不用管。应用更新后如果侧栏又连不上，等自动任务，或手动立即修复：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\chatgpt-chrome-fix\run.ps1"
```

然后在侧栏点 **Try again**。

查看最近的运行记录：

```powershell
Get-Content "$env:LOCALAPPDATA\chatgpt-chrome-fix\fix.log" -Tail 10
```

其他注意：

- 更新后桌面版启动慢或弹「Codex 未响应」：应用在解压运行时，等几分钟即可，不要动 `.staging` 目录
- 不要设置环境变量 `CODEX_CLI_PATH`

## 清单损坏时强制重写

```powershell
$env:CGF_FORCE = "1"
irm https://raw.githubusercontent.com/Ui6oooooo/chatgpt-chrome-fix/main/install.ps1 | iex
```

## 卸载

```powershell
Unregister-ScheduledTask -TaskName "Fix ChatGPT Chrome" -Confirm:$false
Remove-Item "$env:LOCALAPPDATA\chatgpt-chrome-fix" -Recurse -Force
```

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `install.ps1` | 一次性安装：写清单、写注册表、注册计划任务 |
| `run.ps1` | 计划任务入口：拉取最新修复脚本并执行 |
| `fix-chatgpt-chrome.ps1` | 修复脚本：把清单里的路径改成当前版本 |
| `templates/` | 3 个清单模板，`__USERPROFILE__` 会在安装时替换成本机用户目录 |
