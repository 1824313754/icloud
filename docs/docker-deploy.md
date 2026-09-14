# Docker 镜像发布与自动更新

仓库：<https://github.com/1824313754/icloud>。镜像：`ghcr.io/1824313754/icloud`。

本项目参考 `pp-plus` 的 GitHub Actions → GHCR 发布流程。提交到 `main` 后先运行 Go 测试和静态检查，再构建 Linux amd64 镜像，发布 `main`、`latest` 和 `sha-<完整提交号>` 标签。服务器安装下面的 systemd timer 后，每五分钟拉取一次指定标签并更新容器；镜像内容未变化时不会重新创建容器。

## 首次部署到 Linux

需要 Docker Engine、Docker Compose 插件、Git 和 OpenSSL。以下命令在服务器上执行，统一使用 root 的 Docker 登录及 systemd 环境。

```sh
sudo -i
git clone https://github.com/1824313754/icloud.git /opt/icloud
cd /opt/icloud
cp .env.example .env
chmod 600 .env
api_key=$(openssl rand -hex 32)
sed -i "s/^IPM_API_KEY=$/IPM_API_KEY=$api_key/" .env
unset api_key
```

编辑 `.env`：

- `IMAGE_TAG=main`：跟随主分支镜像。
- `IPM_PUBLIC_BASE_URL`：用户实际访问地址，例如 `https://mail.example.com`。
- `BIND_IP=127.0.0.1`、`PORT=8787`：默认仅向服务器本机开放，适合由本机反向代理提供 HTTPS。
- `IPM_API_KEY`：上述步骤生成的健康接口密钥。

GHCR 包若为私有，在服务器交互式运行 `docker login ghcr.io -u 1824313754`，密码栏填写有 `read:packages` 权限的 GitHub PAT。GitHub Actions 发布镜像使用内置 `GITHUB_TOKEN`，不需要另建发布密钥。

先在仓库 Actions 页面确认镜像发布成功，再执行：

```sh
docker compose pull icloud
docker compose up -d --no-build --wait --wait-timeout 120 icloud
curl -fsS http://127.0.0.1:8787/login >/dev/null
docker compose ps
```

通过反向代理访问，或在自己的电脑建立 SSH 转发：

```sh
ssh -L 18787:127.0.0.1:8787 USER@SERVER
```

然后打开 `http://127.0.0.1:18787/login`。新建数据卷的第一个平台注册账号为管理员，之后默认关闭公开注册。Apple 登录态和收信配置在面板内填写。

## 开启自动拉取更新

```sh
install -m 644 deploy/icloud-image-update.service /etc/systemd/system/
install -m 644 deploy/icloud-image-update.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now icloud-image-update.timer
systemctl start icloud-image-update.service
systemctl list-timers icloud-image-update.timer
```

定时任务使用 `/opt/icloud/deploy/update-docker.sh`，先拉取镜像，再以 `--no-build --wait` 更新并检查健康状态。拉取失败时脚本退出，现有容器不变；容器健康检查未通过时，systemd 记录失败，需检查日志。

```sh
journalctl -u icloud-image-update.service -n 50 --no-pager
docker compose logs --tail=100 icloud
```

源码更新随镜像交付；Compose、`.env` 或 systemd 文件本身变更时，仍需同步对应部署文件。暂停自动更新：

```sh
systemctl disable --now icloud-image-update.timer
```

## 持久化与备份

命名卷 `icloud-data` 挂载到 `/data`，实际卷名带 Compose 项目前缀。平台账号、Apple 登录态、邮箱和邮件存放在 `/data/state.db` 等运行文件中，镜像更新及容器重建会保留数据卷。`.env` 单独保存在服务器。

容器默认直接读取环境变量配置，无需创建 `config.json`；如已有 `/data/config.json`，该文件中的非空字段会按应用原有规则覆盖环境变量。容器中的应用自更新关闭，统一通过镜像更新。

备份时先暂停定时任务并停止服务，再复制整个 `/data`：

```sh
systemctl stop icloud-image-update.timer
systemctl stop icloud-image-update.service
docker compose stop icloud
backup_dir="backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
docker compose cp icloud:/data "$backup_dir/data"
cp .env "$backup_dir/.env"
docker compose start icloud
systemctl start icloud-image-update.timer
```

更新及回滚均保留卷；`docker compose down -v` 会删除运行数据。当前 Windows 本机服务的数据不会自动迁移到新 Docker 卷。

## 回滚镜像

先暂停 timer，并将 `.env` 中的 `IMAGE_TAG` 改成之前成功发布的 `sha-<完整提交号>`：

```sh
systemctl stop icloud-image-update.timer
systemctl stop icloud-image-update.service
sh deploy/update-docker.sh
```

这样会部署指定旧镜像，保持同一个数据卷。完成核对后可恢复 timer；固定的 SHA 标签保持指定版本，恢复跟随更新时再将标签改回 `main`。跨数据库格式变化的版本回滚还需配套恢复该版本的数据备份。

## 本地构建验证

配置 `.env` 后可执行 `docker compose up -d --build --wait icloud`。如果本机 `8787` 已被 Windows 服务使用，将 Docker 的 `PORT` 改成 `18787`，并同步修改 `IPM_PUBLIC_BASE_URL`。

标准镜像包含 Go 服务、CA 证书、时区和健康检查工具。需要面板的 Mihomo 代理池功能时，需另行提供对应 Linux Mihomo 程序；普通直连创建及收信不依赖该组件。
