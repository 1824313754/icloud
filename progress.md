## 2026-09-14 - Task: 部署 ic-mail 到当前 Windows 电脑

### What was done

- 拉取指定 GitHub 项目，固定检查版本 `1a49ef9f42be73f583bf9ed2e960c76529c955bb`，完成 Windows 本机编译和后台启动。
- 将复制配置中的访问地址设为本机地址，并生成全局 API 密钥；服务地址为 `http://127.0.0.1:8787/login`。
- 提供启动、停止、配置回滚和操作文档，保留原配置哈希及部署验证证据。

### Testing

- `go test ./...`：退出码 0，`internal/app` 通过，用时 38.847s。
- `go vet ./...`、Windows amd64 `go build`：退出码 0。
- 原始配置、部署配置和回滚副本的 HTTP 检查均返回 PASS，退出码 0；覆盖页面、图形验证码、初始化注册状态以及健康接口密钥校验。
- 回滚副本 SHA-256 与原模板完全相同；正式配置仍保持部署后的哈希。
- 后台启动、停止释放端口、重新启动和重复启动检查通过。真实服务最终 HTTP 检查返回 `LIVE=PASS`，退出码 0。
- SQLite `PRAGMA quick_check` 返回 `ok`；最终检查时已经存在一个平台账号，因此正式环境关闭公开注册符合默认行为。Apple 登录及真实收信尚未验证。
- 完整命令、输入、输出和退出码见 `.codex-deploy/VERIFICATION.txt`。

### Notes

- 源码基线：本轮克隆上游仓库；原有已跟踪文件未修改。
- `config.json`：从模板复制，配置本机 URL 和随机 API 密钥；由上游忽略规则排除。
- `bin/icloud-privacy-mail.exe`：本轮生成的 Windows 程序，写入源码 commit 与构建时间。
- `deploy/start-local.ps1`：新增后台启动、重复启动检查和页面就绪验证。
- `deploy/stop-local.ps1`：新增按本项目程序路径定位并停止服务的操作。
- `docs/local-deployment.md`：新增使用、数据备份、启动停止及回滚说明。
- `progress.md`：新增本轮部署记录。
- `.codex-deploy/config.original.json`、`original.sha256`、`modified.sha256`：保存原始配置及改动前后 SHA-256。
- `.codex-deploy/DIFF_FILE.diff`：保存配置差异，省略密钥原文。
- `.codex-deploy/smoke.py`：新增隔离配置验证及真实服务 HTTP 检查脚本。
- `.codex-deploy/ROLLBACK.sh`：新增可执行回滚脚本，可对指定副本恢复原始配置。
- `.codex-deploy/VERIFICATION.txt`：汇总完整验证证据和四项交付路径。
- `.codex-deploy/` 其余文件：本轮测试输出、退出码、隔离测试数据库和回滚测试副本；整个目录由上游忽略规则排除。
- `data/`、`logs/`：服务生成的本地数据与运行日志；整个目录由上游忽略规则排除。
- 可执行回滚方式：在项目目录运行 `& 'E:\Git\bin\bash.exe' .codex-deploy/ROLLBACK.sh`，停止本次服务并恢复模板配置，保留数据库及项目文件。
- 本次为本机后台运行，未配置开机自启；电脑重启后按文档启动。

## 2026-09-14 - Task: 提交到 1824313754/icloud 并配置 Docker 镜像发布与自动更新

### What was done

- 参考 `C:\Users\wangjie\Desktop\pp-plus` 的 Actions → GHCR 发布方式，为本项目新增提交到 `main` 后测试、构建和发布镜像的流程。
- 镜像名称设为 `ghcr.io/1824313754/icloud`，发布 `main`、`latest` 及 `sha-<完整提交号>` 标签，支持固定版本回滚。
- 提供 Docker Compose、独立持久化数据卷及 Linux 每五分钟拉取更新的 systemd timer；配置及数据库不进入 Git 提交和镜像构建上下文。
- 将指定仓库配置为 `origin`，保留原作者仓库为 `upstream`；现有 Windows 本机服务继续运行。

### Testing

- `go test ./...`、`go vet ./...`：退出码均为 0，现有 Go 业务源码保持原样。
- `docker compose config --quiet`：退出码 0；环境变量缺失时按配置要求提示补齐。
- `go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 .github/workflows/docker-publish.yml`：退出码 0。
- Linux Docker 镜像实际构建通过，退出码 0。
- 隔离容器检查返回 `MODIFIED=PASS`：登录页 200、健康接口无密钥 401/正确密钥 200、首个管理员创建成功、UID=10001、SQLite 位于数据卷。
- 删除并重建测试容器后，管理员账号及登录会话均保留；Docker 健康状态为 `healthy`。测试容器及测试卷已清理。
- `bash -n deploy/update-docker.sh`、工作流 YAML 与 Git 忽略规则检查通过，运行配置、数据、日志及本地验证产物均被排除。
- 本机尚无指定的远程 Linux 部署目标；systemd timer 已准备，实际启用步骤见文档。GitHub 发布及回滚验证证据继续保存在本机 `.codex-deploy/github-docker-20260914/`。

### Notes

- `.github/workflows/docker-publish.yml`：新增主分支测试和 GHCR 镜像发布流程。
- `Dockerfile`：新增 Go 多阶段构建、非 root 运行和容器健康检查。
- `.dockerignore`：使用构建文件白名单，避免运行数据进入镜像上下文。
- `.gitattributes`：保证 shell 脚本使用 LF 行尾。
- `.env.example`：新增镜像标签、监听地址和部署配置模板。
- `.gitignore`：追加环境文件忽略规则，保留无密钥模板。
- `docker-compose.yml`：新增服务、健康等待支持和持久化命名卷。
- `deploy/update-docker.sh`：新增拉取镜像并按健康检查更新的入口。
- `deploy/icloud-image-update.service`、`deploy/icloud-image-update.timer`：新增固定部署路径 `/opt/icloud` 的定时更新服务。
- `README.md`、`docs/docker-deploy.md`：补充镜像发布、首次部署、定时更新、备份及回滚说明。
- `progress.md`：追加本轮实施和验证记录。
- `deploy/start-local.ps1`、`deploy/stop-local.ps1`、`docs/local-deployment.md`：将前一轮已验证的本机部署交付一并纳入提交。
- `.git/config`：将 `origin` 指向用户指定仓库，原仓库重命名为 `upstream`。
- `.codex-deploy/github-docker-20260914/`：保存参考文件原始哈希、验证输出、部署差异和可执行回滚脚本，属于本机产物，不提交。
- 代码回滚点：本轮变更前提交 `1a49ef9f42be73f583bf9ed2e960c76529c955bb`；使用 `git revert <本轮部署提交号>` 创建反向提交。
- 运行版本回滚：暂停 `icloud-image-update.timer`，将 `.env` 的 `IMAGE_TAG` 改为既有 `sha-<提交号>`，执行 `sh deploy/update-docker.sh`，保留数据卷。

## 2026-09-14 - Task: 核对首次发布并补充 CI 失败诊断

### What was done

- 已将部署提交 `b769be618dafd0b080cdc01fc81347b5072ae363` 推送到指定仓库 `main`。
- 首次 Actions 在测试步骤失败，公开页面仅显示退出码；将 Go 测试失败输出写入 Actions 注释，以便直接定位具体失败，测试失败仍会阻止镜像发布。

### Testing

- Linux 构建容器实际执行 `go test ./...` 通过，`internal/app` 用时 27.521s。
- 回滚脚本已在独立克隆上执行；源码树恢复为原始提交，新增镜像发布流程被移除。
- 回滚副本首轮测试出现 `TestMailboxVisualRefreshKeepsBackgroundSyncAliveAfterFastResponse` 临时目录清理失败；完整复验通过，用时 34.878s，未改动业务源码或测试。
- 参考仓库仅作只读参考；正式工作区和运行数据保持部署状态。

### Notes

- `.github/workflows/docker-publish.yml`：补充失败时的具体测试输出，不改变测试通过条件。
- `progress.md`：追加远程首轮构建和回滚复验的真实结果。
- `.codex-deploy/github-docker-20260914/`：保存失败、复验和回滚证据。
- 回滚方式：对本轮诊断提交执行 `git revert <提交号>`；完整部署回滚仍以 `1a49ef9f42be73f583bf9ed2e960c76529c955bb` 为基线。
