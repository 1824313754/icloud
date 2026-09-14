# 本机部署说明

部署日期：2026-09-14。部署目标：当前 Windows 电脑。

- 访问地址：http://127.0.0.1:8787/login
- 项目目录：`C:\Users\wangjie\Desktop\icloud\ic-mail`
- 源码版本：`1a49ef9f42be73f583bf9ed2e960c76529c955bb`
- 程序版本：`2026.08.14.6`，使用 Go 1.26.2 编译为 Windows amd64。
- 服务监听 `127.0.0.1:8787`，访问范围为本机。

## 使用

打开登录页，使用平台账号登录。首次注册的账号自动成为管理员；本次交付检查时，数据库已经有一个平台账号。首个账号建立后，默认关闭公开注册。

Apple 登录和真实收信需在面板内完成配置与验证。需要创建隐私邮箱时使用具备对应权益的 Apple 账号；IMAP 收信需要 iCloud 邮箱及 App 专用密码。交付检查中的 `icloud_active=false` 表示尚未确认 Apple 业务连接。

## 启动与停止

在 PowerShell 中进入项目目录后执行：

```powershell
Set-Location 'C:\Users\wangjie\Desktop\icloud\ic-mail'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File deploy/start-local.ps1
```

启动脚本在后台运行服务，返回 `RUNNING http://127.0.0.1:8787/login`。重复执行会检查已运行实例。当前未配置开机或登录自动启动，重启电脑后执行上述命令。

停止服务：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File deploy/stop-local.ps1
```

日志位于 `logs/panel.stdout.log` 和 `logs/panel.stderr.log`，每次新启动会重新写入这两个运行日志。

## 配置与数据

运行配置为 `config.json`，由原配置模板复制产生，仅调整：

- `public_base_url`：改为 `http://127.0.0.1:8787`。
- `api_key`：生成随机 64 位十六进制密钥，用于健康接口。密钥保存在本机配置中。

存储继续使用项目默认的 SQLite。配置中的 `data_path=data/state.json` 对应实际主数据库 `data/state.db`；备份时应先停止服务并保留整个 `data/` 目录及 `config.json`，不要只复制 `state.json`。数据库完整性检查返回 `ok`。

## 验证与回滚

项目自带 `go test ./...`、`go vet ./...`、Windows 编译均已通过。登录页、注册页、图形验证码、健康接口、停止及重新启动已经验证。具体命令、输入、输出、退出码和配置 SHA-256 见 [VERIFICATION.txt](../.codex-deploy/VERIFICATION.txt)。

`.codex-deploy/DIFF_FILE.diff` 记录部署配置差异，密钥内容已省略。`.codex-deploy/config.original.json` 保存原始模板字节，原模板文件保持原样。

回滚本次运行配置并停止服务：

```powershell
& 'E:\Git\bin\bash.exe' .codex-deploy/ROLLBACK.sh
```

回滚后，`config.json` 恢复为原模板，后台服务停止，数据库、源码和程序保留。原模板的 URL 是示例值，重新部署时应恢复本机 URL 和密钥。

回滚已在单独的配置副本上执行，并通过 SHA-256 一致性和原配置行为验证；正式 `config.json` 保持部署后的内容。
