# SSR V2 Manager

一个面向 **Ubuntu / Debian + systemd** 的 ShadowsocksR-native 单文件安装与管理脚本。

首次运行可以完成安装，后续可直接通过数字菜单管理 SSR，包括端口、密码、加密方式、协议、混淆、UDP、BBR、防火墙、日志、二维码、配置备份/恢复以及源码更新等功能。

> 仅应在你拥有或获准管理的服务器和网络环境中使用，并遵守所在地法律法规、云服务商条款和网络管理要求。

## 支持环境

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Debian 11
- Debian 12
- Debian 13（按脚本兼容逻辑支持，建议部署前自行验证）
- systemd
- x86_64 / amd64 为主要测试目标
- 需要 root 权限

## 上游项目

本脚本安装和管理的服务端来自：

- ShadowsocksR-native: https://github.com/ShadowsocksR-Live/shadowsocksr-native

本仓库是管理脚本，不包含上游项目源码。安装时会从上游仓库拉取源码并在服务器本地编译。

## 主要功能

运行脚本后提供完整数字菜单：

```text
============================================================
              SSR V2 一键安装 / 管理脚本 v2.0.1
============================================================
 1. 安装 SSR                 16. 查看 BBR 状态
 2. 卸载 SSR                 17. 防火墙放行当前端口
 3. 启动 SSR                 18. 生成 SSR 链接
 4. 停止 SSR                 19. 生成 SSR 二维码
 5. 重启 SSR                 20. 更新 SSR 源码/程序
 6. 查看运行状态             21. 重新编译安装（保留配置）
 7. 查看连接信息             22. 系统环境检测
 8. 修改端口                 23. 查看监听端口
 9. 修改密码                 24. 查看服务器公网 IP
10. 修改加密方式             25. 备份配置
11. 修改协议                 26. 恢复配置
12. 修改混淆                 27. 一键网络优化
13. 开启/关闭 UDP            28. 查看完整配置
14. 查看实时日志             29. 重置 SSR 配置
15. 开启 BBR                  0. 退出
============================================================
```

### 安装与生命周期

- 快速安装：随机端口 + 随机密码 + 默认推荐参数
- 自定义安装
- 卸载 SSR
- 启动 / 停止 / 重启
- systemd 开机自启
- 更新上游源码并重新编译
- 保留配置重新编译安装

### 配置管理

- 修改监听端口
- 修改密码
- 修改加密方式
- 修改协议
- 修改混淆
- 开启 / 关闭 UDP
- 查看完整 JSON 配置
- 重置为新的随机端口和密码
- 修改配置前自动备份
- 手动备份 / 恢复配置

### 运维功能

- 查看 systemd 状态
- 查看实时 journal 日志
- 查看监听端口
- 获取服务器公网 IPv4
- 系统环境检测
- 开启和检查 BBR
- 保守型 TCP 参数优化
- 自动处理已启用的 UFW / firewalld 端口规则

### 客户端导入

- 显示完整连接参数
- 生成 `ssr://` 链接
- 终端输出二维码
- 可生成 `/root/ssr-qrcode.png`

## 快速开始

### 一行安装（推荐）

Ubuntu / Debian 服务器直接复制下面这一行执行：

```bash
tmp=$(mktemp) && (curl -fsSL https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh -o "$tmp" || wget -qO "$tmp" https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh) && sudo bash "$tmp"; rm -f "${tmp:-}"
```

这条命令会：

1. 创建临时脚本文件；
2. 优先使用 `curl` 下载，失败时自动尝试 `wget`；
3. 使用 `sudo bash` 启动 SSR V2 Manager；
4. 脚本首次运行时安装 `ssr` 管理命令；
5. 退出菜单后自动删除临时下载文件。

安装完成后，以后直接运行：

```bash
sudo ssr
```

即可再次进入管理菜单。

> 安全提示：一行安装会从本仓库 `main` 分支下载脚本并以 root 权限运行。如果是生产服务器或对供应链安全有较高要求，建议先下载脚本、阅读源码并执行 `bash -n ssr-v2-manager.sh` 检查后再运行。

### 仅使用 curl

服务器已安装 `curl` 时，也可以使用：

```bash
curl -fsSL https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh -o /tmp/ssr-v2-manager.sh && sudo bash /tmp/ssr-v2-manager.sh
```

### 仅使用 wget

服务器没有 `curl` 时：

```bash
wget -qO /tmp/ssr-v2-manager.sh https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh && sudo bash /tmp/ssr-v2-manager.sh
```

### 手动安装

如果希望先检查脚本再运行，可以手动下载：

```bash
wget https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh
chmod +x ssr-v2-manager.sh
bash -n ssr-v2-manager.sh
sudo ./ssr-v2-manager.sh
```

首次运行脚本会尝试把管理器安装到：

```text
/usr/local/sbin/ssr-manager
```

并创建快捷命令：

```text
/usr/local/bin/ssr
```

以后直接运行：

```bash
sudo ssr
```

即可进入数字菜单。

## 非交互命令

除菜单外，还提供若干快捷命令：

```bash
sudo ssr status
sudo ssr start
sudo ssr stop
sudo ssr restart
sudo ssr info
sudo ssr link
sudo ssr logs
sudo ssr env
ssr --version
ssr --help
```

## 默认参数

快速安装默认使用：

```text
端口：20000-50000 随机未占用端口
密码：32 位十六进制随机密码
加密：aes-128-ctr
协议：auth_aes128_md5
混淆：tls1.2_ticket_auth
UDP：开启
```

所有核心参数都可在安装后通过数字菜单修改。

## 支持的加密方式

菜单目前提供：

```text
aes-128-ctr
aes-192-ctr
aes-256-ctr
aes-128-cfb
aes-192-cfb
aes-256-cfb
chacha20
chacha20-ietf
rc4-md5
none
```

实际是否可用取决于上游 ShadowsocksR-native 当前版本。

## 支持的协议

```text
auth_aes128_md5
auth_aes128_sha1
auth_chain_a
auth_chain_b
auth_sha1_v4
origin
```

## 支持的混淆

```text
tls1.2_ticket_auth
tls1.2_ticket_fastauth
http_simple
http_post
http_mix
plain
```

## 配置与文件位置

```text
源码目录：        /opt/shadowsocksr-native
服务端程序：      /usr/local/bin/ssr-server
配置目录：        /etc/ssr-native
配置文件：        /etc/ssr-native/config.json
配置备份：        /etc/ssr-native/backups
systemd 服务：    /etc/systemd/system/ssr-native.service
管理脚本：        /usr/local/sbin/ssr-manager
快捷命令：        /usr/local/bin/ssr
BBR 配置：         /etc/sysctl.d/99-ssr-bbr.conf
网络优化配置：    /etc/sysctl.d/99-ssr-network-tuning.conf
```

## 云服务器防火墙

脚本只能管理服务器操作系统内部已经启用的 UFW / firewalld。

如果服务器部署在阿里云、腾讯云、华为云等平台，还必须在云控制台的防火墙 / 安全组中额外放行 SSR 当前端口。

例如 SSR 端口是 `23456`：

```text
TCP 23456
UDP 23456
```

修改端口后，也要同步调整云控制台规则。

## BBR

菜单选择：

```text
15. 开启 BBR
```

脚本会检测当前 Linux 内核是否提供 BBR，并配置：

```text
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
```

使用：

```text
16. 查看 BBR 状态
```

可以查看当前拥塞控制算法。

## SSR 链接和二维码

选择：

```text
18. 生成 SSR 链接
```

会根据当前配置生成 `ssr://` 链接。

选择：

```text
19. 生成 SSR 二维码
```

会：

1. 在终端显示 ANSI 二维码；
2. 把 PNG 保存到：

```text
/root/ssr-qrcode.png
```

## 配置备份

配置备份目录：

```text
/etc/ssr-native/backups
```

脚本在修改重要参数前会自动创建备份。

也可以手动使用：

```text
25. 备份配置
26. 恢复配置
```

## 查看日志

```bash
sudo journalctl -u ssr-native -f
```

或者菜单：

```text
14. 查看实时日志
```

退出实时日志：

```text
Ctrl+C
```

## 常见问题

### 1. 服务已经运行，但客户端连接不上

优先检查：

```bash
sudo ssr status
sudo ssr info
sudo ss -lntup | grep ssr
```

然后确认：

- 云平台防火墙 / 安全组已放行当前 TCP 端口；
- 如果需要 UDP，云平台也已放行 UDP；
- 客户端密码、加密、协议和混淆与服务器完全一致；
- 服务端公网 IP 正确。

### 2. 修改端口后无法连接

脚本会更新本机 UFW/firewalld（如果它们已启用），但不能直接修改云厂商控制台安全组。

需要手动给新端口添加：

```text
TCP
UDP
```

规则。

### 3. 编译失败

执行：

```bash
sudo ssr env
```

检查系统、架构和 GitHub 连通性。

也可以查看完整错误信息后重新尝试：

```text
21. 重新编译安装（保留配置）
```

### 4. 如何完整卸载

菜单执行：

```text
2. 卸载 SSR
```

SSR 服务、服务端二进制和源码会被删除。

管理脚本本身会保留，因此仍然可以运行：

```bash
sudo ssr
```

重新安装。

## 安全建议

- 使用随机强密码，不要使用弱口令。
- 不要把 SSR 配置文件或带密码的 `ssr://` 链接提交到公开 GitHub 仓库。
- `/etc/ssr-native/config.json` 默认被脚本设置为 `600` 权限。
- 云安全组尽量只开放实际需要的服务端口。
- SSH 建议使用密钥认证并限制 root 密码登录。
- 定期检查 `journalctl`、系统更新和异常连接。
- 不建议公开暴露 Redis、MySQL、内部管理 API 等服务。

## 脚本自检

下载脚本后可以先进行 Bash 语法检查：

```bash
bash -n ssr-v2-manager.sh
```

查看版本：

```bash
./ssr-v2-manager.sh --version
```

## 注意事项

ShadowsocksR 属于较老的协议栈。上游项目的兼容性、协议实现和依赖可能发生变化，因此建议在生产环境部署前先在测试服务器验证。

本脚本不会自动修改云厂商控制台的防火墙、安全组、备案或账号配置。

## 版本

当前管理脚本：

```text
SSR V2 Manager 2.0.1
```
