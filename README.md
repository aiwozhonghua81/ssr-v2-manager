# SSR V2 Manager

> 一个**单文件 Bash 脚本**，把「在服务器上装一个 ShadowsocksR 代理服务」这件事，压缩成**复制一行命令 + 点几个数字**。

---

## 你是不是遇到过这种情况？

你买了一台海外服务器（阿里云、腾讯云、华为云、Vultr、搬瓦工都算），想用它给自己搭个代理。

然后你打开终端，发现要干这些事：

1. 装编译工具（`build-essential`、`git`、`curl`……）
2. 去 GitHub 上找 ShadowsocksR 的源码，下载、解压
3. `bash setup.sh install` 跑安装脚本
4. 手写 `config.json`，填 IP、端口、密码、加密方式、协议、混淆
5. 写一个 systemd 服务文件，让它开机自启
6. `systemctl enable --now` 启动
7. 手动开防火墙端口（UFW / firewalld 挑一个）
8. 去云控制台的安全组里再放行一遍 TCP 和 UDP
9. 生成客户端能扫的二维码
10. 万一要改个参数，还得重新翻配置文件

**这 10 步里每一步都可能踩坑**，而且改一次端口你要重复 4、5、7、8 四步。

**这个脚本就是把这些全包了。** 你只需要：

```bash
sudo ssr
```

然后按数字键。

---

## 目录导航

| 章节 | 内容 |
| --- | --- |
| [一、这是什么](#一这是什么) | 一句话说明 |
| [二、适合谁用](#二适合谁用) | 什么时候该用它 |
| [三、效果速览](#三效果速览) | 手动装 vs 用这个项目 |
| [四、核心功能](#四核心功能) | 30 个菜单项逐个解释 |
| [五、环境要求](#五环境要求) | 系统、内存、权限 |
| [六、快速上手](#六快速上手) | 从零到能用，3 步 |
| [七、详细说明](#七详细说明) | 命令、参数、文件位置、加密/协议/混淆清单 |
| [八、目录结构](#八目录结构) | 仓库里有什么 |
| [九、常见问题排查](#九常见问题排查) | 现象 → 原因 → 怎么办 |
| [十、新手最常犯的 5 个错](#十新手最常犯的-5-个错) | 踩坑预警 |
| [十一、安全注意事项](#十一安全注意事项) | 该做和不该做的 |
| [十二、卸载与回滚](#十二卸载与回滚) | 怎么干净地撤掉 |
| [十三、许可证与致谢](#十三许可证与致谢) | 上游项目 |

---

<a id="一这是什么"></a>
## 一、这是什么

**一句话**：这是一个 Linux 服务器上的「ShadowsocksR 一键安装 + 可视化菜单管理」脚本。

先把几个名词翻译成人话：

- **代理（Proxy）**：让你的电脑流量「绕道」到另一台服务器上再出去，中间加密，途中的人看不到你在访问什么。
- **ShadowsocksR（简称 SSR，一种老牌的代理协议）**：2014 年前后很流行的一套加密代理方案，特点是**协议和混淆可以自由组合**，在很多网络环境下比裸 TCP 更不容易被识别。缺点是年代久远，现在属于「老将」而不是「主流」。
- **Ubuntu / Debian**：两种最常见的 Linux 发行版，绝大多数海外云服务器预装的就是它们。
- **systemd**：Linux 的服务管理器，负责「开机自动启动」「崩溃自动重启」这类事。
- **加密方式 / 协议 / 混淆**：SSR 的三件套参数，见 [七、详细说明](#七详细说明)。

**本脚本做的事**：把上游的 [ShadowsocksR-native](https://github.com/ShadowsocksR-Live/shadowsocksr-native) 编译成可执行文件，写好配置文件，注册成 systemd 服务，配置防火墙，然后给你一个**中文数字菜单**用来日常管理。

**本脚本不做什么**：它不修改你的云厂商控制台安全组（那必须你自己去点），也不提供任何绕过网络管制的承诺。请在合法的场景下使用。

---

<a id="二适合谁用"></a>
## 二、适合谁用 / 能解决什么问题

**适合：**

- 有一台自己的 **Ubuntu / Debian 云服务器**，想装 SSR 代理但不想折腾命令行
- 已经知道「端口 / 密码 / 加密 / 协议 / 混淆」这些词是什么意思，只是懒得一次次 SSH 上去改配置
- 需要**经常换端口**、**换密码**、**换节点名字**（比如按城市自动命名）
- 想给 VPS 做**基础网络优化**（BBR 拥塞控制、TCP 参数调优）
- 想把一整台服务器**一键撤干净**（卸载）

**不适合：**

- ❌ Windows / macOS 本机 —— 这是**服务器端**脚本，你的电脑要装的是**客户端**
- ❌ CentOS / RHEL / Alpine —— 代码里明确只放行 `ubuntu` 和 `debian`，其他系统会直接报错退出
- ❌ 没有 systemd 的系统（比如 Docker 精简镜像、OpenWrt）—— 会提示「系统未使用 systemd」
- ❌ 想装更新的 Shadowsocks / VMess / VLESS / Trojan —— 那些是别的项目，本脚本只管 SSR
- ❌ 需要多用户、多节点、流量统计、订阅链接管理 —— 本脚本是**单节点**轻量工具

**它解决的核心问题：**

| 你想做的事 | 手动操作 | 用这个脚本 |
| --- | --- | --- |
| 装一个能用的 SSR | 10 步，每步都可能失败 | 1 步 |
| 换个端口 | 改 JSON + 改 systemd + 改 UFW + 改安全组 | 菜单 `8`，1 步 |
| 给手机/电脑用 | 手动拼 `ssr://` 链接 | 菜单 `18` / `19`，直接扫二维码 |
| 看现在有多少人连着 | `ss -ntp` + `journalctl` 硬查 | 菜单 `7` / `6` |
| 服务器崩了服务没了 | 手动排查 | systemd 自动重启 + 菜单 `14` 看日志 |

---

<a id="三效果速览"></a>
## 三、效果速览

### 手动装 vs 用这个项目

| 步骤 | 手动操作 | 用 SSR V2 Manager |
| --- | --- | --- |
| 1. 装编译依赖 | 手动敲 `apt install` 一堆包 | 自动 |
| 2. 下载 SSR 源码 | 手动 git clone / wget zip | 自动 |
| 3. 编译 | 手动 `bash setup.sh install` | 自动 |
| 4. 写配置文件 | 手动写 JSON | 自动（随机端口 + 随机密码） |
| 5. 注册开机自启 | 手写 systemd unit 文件 | 自动 |
| 6. 启动服务 | `systemctl enable --now` | 自动 |
| 7. 开本机防火墙 | 手动敲 `ufw allow` | 自动（UFW / firewalld 都识别） |
| 8. 开云安全组 | **只能手动**，去控制台点 | **仍然要手动**（脚本管不到） |
| 9. 生成客户端链接 | 手动 base64 拼 `ssr://` | 菜单 `18` 一键生成 |
| 10. 生成二维码 | 装 qrencode 之类 | 菜单 `19`，自动存 PNG |
| 11. 改端口 | 重复第 4/5/7/8 步 | 菜单 `8` |
| 12. 改密码 | 手动改 JSON 再重启 | 菜单 `9` |
| 13. 换加密/协议/混淆 | 手动改 JSON 再重启 | 菜单 `10`/`11`/`12` |
| 14. 开 BBR | 手动写 sysctl 配置 | 菜单 `15` |
| 15. 看日志 | `journalctl -u ... -f` | 菜单 `14` |
| 16. 更新 SSR | 手动 git pull + 重编译 | 菜单 `20`（连管理脚本一起更新） |
| 17. 备份配置 | 手动 cp | 菜单 `25`（改参数前还会自动备份） |
| 18. 彻底卸载 | 手动 rm 一堆文件 | 菜单 `2` |

### 装完之后长什么样

```text
================ SSR 连接信息 ================
状态       : active
节点名称   : 洛杉矶-1.2.3.4-23456
城市       : 洛杉矶
服务器     : 1.2.3.4
端口       : 23456
密码       : 8f3a...（32 位十六进制随机串）
加密       : aes-128-ctr
协议       : auth_aes128_md5
混淆       : tls1.2_ticket_auth
UDP        : true
=============================================
```

> 上面 IP、端口、密码都是**示意值**，你实际装出来会不一样。

---

<a id="四核心功能"></a>
## 四、核心功能

运行 `sudo ssr` 后你会看到完整菜单：

```text
============================================================
              SSR V2 一键安装 / 管理脚本 v2.0.3
============================================================
 1. 安装 SSR                 16. 查看 BBR 状态
 2. 卸载 SSR                 17. 防火墙放行当前端口
 3. 启动 SSR                 18. 生成 SSR 链接
 4. 停止 SSR                 19. 生成 SSR 二维码
 5. 重启 SSR                 20. 更新 SSR + 管理脚本
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

### 菜单逐项人话解释

| 编号 | 菜单 | 人话解释 |
| --- | --- | --- |
| 1 | **安装 SSR** | 第一次用就走这个。会让你选「快速安装」（随机端口 + 随机密码 + 推荐参数）或「自定义安装」（自己指定端口密码加密协议混淆）。 |
| 2 | **卸载 SSR** | 把 SSR 服务端、编译出来的程序、源码目录、当前配置全删掉。**管理脚本 `ssr` 命令会保留**，所以你还能随时再装回来。 |
| 3 | **启动 SSR** | 启动服务。systemd 写的配置是开机自启，所以重启服务器后一般不需要手动启动。 |
| 4 | **停止 SSR** | 暂停服务。人在国外服务器上时不想被连接时用。 |
| 5 | **重启 SSR** | 改了端口/密码/加密方式之后必须重启才生效，脚本内部已经帮你串好了。 |
| 6 | **查看运行状态** | 看 `systemctl status` 的完整输出：跑了多久、占多少内存、最近几行日志。**判断「装成功没有」就看这里。** |
| 7 | **查看连接信息** | 一屏显示：状态、节点名、城市、公网 IP、端口、密码、加密、协议、混淆、UDP 开关。**抄参数给客户端就看这里。** |
| 8 | **修改端口** | 换监听端口。会**自动**同步本机 UFW / firewalld 规则。**云安全组要你自己去改。** |
| 9 | **修改密码** | 换连接密码。改完自动重启。 |
| 10 | **修改加密方式** | 换加密算法（aes-128-ctr 等 10 种）。**客户端必须同步改**，否则连不上。 |
| 11 | **修改协议** | 换协议（auth_aes128_md5 等 6 种）。**客户端必须同步改。** |
| 12 | **修改混淆** | 换混淆方式（tls1.2_ticket_auth 等 6 种）。**客户端必须同步改。** |
| 13 | **开启/关闭 UDP** | UDP 转发主要影响 DNS 解析速度（游戏、语音更跟手）。默认开启。 |
| 14 | **查看实时日志** | 滚动显示服务日志，看连接建立/断开。按 `Ctrl+C` 退出。 |
| 15 | **开启 BBR** | 给 TCP 装上 BBR 拥塞控制算法，**在丢包高的线路上能明显提速**。需要内核支持。 |
| 16 | **查看 BBR 状态** | 看内核版本、可用算法、当前算法、队列算法、模块是否加载。 |
| 17 | **防火墙放行当前端口** | 一键把当前 SSR 端口的 TCP + UDP 加进 UFW / firewalld。**并会提醒你去云控制台放行。** |
| 18 | **生成 SSR 链接** | 生成一条 `ssr://` 开头的链接，复制到客户端就能用。 |
| 19 | **生成 SSR 二维码** | 终端直接画二维码，同时存一份 PNG 到 `/root/ssr-qrcode.png`，手机扫一扫就能导入。 |
| 20 | **更新 SSR + 管理脚本** | 从本仓库 `main` 分支拉最新版脚本 + 从上游拉最新版 SSR 源码重新编译。**一次更新两样。** |
| 21 | **重新编译安装（保留配置）** | SSR 源码损坏或换了系统时，重新编译一次，**配置（端口密码等）保留不变**。 |
| 22 | **系统环境检测** | 打印系统版本、架构、内核、CPU 核心数、内存、磁盘、公网 IP、systemd 版本、SSR 状态、BBR 状态、GitHub 连通性。**排查问题第一步就跑这个。** |
| 23 | **查看监听端口** | 列出系统上所有监听端口，并高亮 SSR 端口和 `ssr-server` 进程。用来确认「服务真的在监听」。 |
| 24 | **查看服务器公网 IP** | 显示公网 IPv4、所在城市（自动识别）、本机所有网卡地址。 |
| 25 | **备份配置** | 把当前 `config.json` 复制一份到备份目录（带时间戳）。 |
| 26 | **恢复配置** | 列出所有历史备份让你选，恢复后会重开防火墙端口并重启服务。 |
| 27 | **一键网络优化** | 应用一组**保守型** TCP 参数（somaxconn、backlog、keepalive、MTU 探测）。**不改 DNS、不改路由、不动防火墙。** |
| 28 | **查看完整配置** | 格式化打印整个 `config.json`（用 jq 美化过）。 |
| 29 | **重置 SSR 配置** | 生成**新的随机端口 + 新的随机密码**，并把加密/协议/混淆恢复成推荐值。旧的配置会先自动备份。**适合「怀疑密码泄露了」的场景。** |
| 0 | **退出** | 退出菜单。 |

---

<a id="五环境要求"></a>
## 五、环境要求

| 项目 | 要求 | 说明 |
| --- | --- | --- |
| 操作系统 | **Ubuntu** 或 **Debian** | 脚本里 `check_os` 只放行 `ID=ubuntu` / `ID=debian`，其他发行版会直接报错退出 |
| 已验证版本 | Ubuntu 22.04 LTS、Ubuntu 24.04 LTS、Debian 11、Debian 12 | Debian 13 按兼容逻辑支持，**建议先在测试机验证** |
| 系统管理器 | **systemd** | 没有 systemd 会提示「系统未使用 systemd」并退出 |
| CPU 架构 | **x86_64 / amd64**（主要测试目标） | 编译依赖 C/C++ 工具链 |
| 内存 | **建议 ≥ 512 MB** | 编译阶段需要内存，小于 256 MB 的小鸡编译可能失败 |
| 磁盘 | **建议 ≥ 2 GB 可用空间** | 源码 + 编译产物 + 备份 |
| 权限 | **root**（或能 `sudo`） | 要写 `/usr/local`、`/etc`、`/opt`，要动 systemd 和防火墙 |
| 网络 | 能访问 **github.com** 和 **raw.githubusercontent.com** | 装依赖、下载源码、编译、后续自更新都要用 |
| 客户端 | 支持 SSR 的客户端 | Windows / macOS / iOS / Android 都有现成的 |

---

<a id="六快速上手"></a>
## 六、快速上手

### 第 1 步：SSH 登录你的服务器

在本地终端（Windows 建议用 PowerShell 或 Git Bash，macOS/Linux 用系统自带终端）：

```bash
ssh root@你的服务器IP
```

**成功标志**：你看到类似 `root@your-server:~#` 的提示符（结尾的 `#` 表示你现在是 root）。

> 如果你的云服务器用的是 `ubuntu` 用户而不是 `root`，后面的命令前面加 `sudo` 即可。

### 第 2 步：粘贴这一行，按回车

```bash
tmp=$(mktemp) && (curl -fsSL https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh -o "$tmp" || wget -qO "$tmp" https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh) && sudo bash "$tmp"; rm -f "${tmp:-}"
```

**这行命令在干什么**：

1. `mktemp` —— 在 `/tmp` 造一个临时文件名，避免和已有文件冲突
2. `curl -fsSL` 下载脚本；**如果服务器没装 curl**，自动改用 `wget`
3. `sudo bash "$tmp"` —— 用 root 权限运行脚本（脚本内部会自己检查权限）
4. `rm -f` —— 删掉临时文件，不留垃圾

**成功标志**：屏幕上出现下面这个菜单框：

```text
============================================================
              SSR V2 一键安装 / 管理脚本 v2.0.3
============================================================
 1. 安装 SSR                 16. 查看 BBR 状态
...
```

脚本会先自动把管理命令装到系统里（`/usr/local/sbin/ssr-manager` + 快捷命令 `/usr/local/bin/ssr`）。

### 第 3 步：选择 `1` 安装 SSR

在菜单里输入 `1` 然后回车。接着会让你选安装方式：

```text
1. 快速安装（随机端口 + 随机密码 + 推荐参数）
2. 自定义安装
0. 返回
```

**新手直接选 `1`**（快速安装）。理由：随机端口不容易撞车，随机密码不会被人猜到，加密/协议/混淆用的是兼容性最好的组合。

输入 `1` 回车 → 脚本会打印即将安装的参数：

```text
即将安装：端口=23456，加密=aes-128-ctr，协议=auth_aes128_md5，混淆=tls1.2_ticket_auth，UDP=true
确认开始安装？[y/N]
```

输入 `y` 回车。

**成功标志**：最后看到这两行：

```text
[+] SSR 安装完成
================ SSR 连接信息 ================
状态       : active
...
```

### 第 4 步（重要）：去云控制台放行端口

菜单里显示的端口（比如 `23456`），**你必须去云厂商控制台手动放行**，否则外面连不上。

- 阿里云 / 腾讯云 / 华为云 → 找到「安全组」→ 「入方向规则」→ 添加 **TCP** 和 **UDP** 两条，端口填 SSR 端口
- 如果是 Vultr / 搬瓦工这类 → 找「Firewall」设置

**成功标志**：安全组规则列表里能看到 `TCP:你的端口` 和 `UDP:你的端口` 两条。

### 第 5 步：把参数导入客户端

在菜单里输入 `19`（生成 SSR 二维码），或者输入 `18`（生成 SSR 链接）。

二维码会直接画在终端里，同时 PNG 存到了 `/root/ssr-qrcode.png`。

用手机上的 SSR 客户端（安卓常见的是 shadowsocks 客户端类、Clash 系；iOS 是 Shadowrocket 等）**扫码**或者**粘贴链接**，然后把客户端里的端口、密码、加密、协议、混淆**改成和服务端一模一样**。

### 第 6 步：验证

在菜单里输入 `6`（查看运行状态）：

```bash
sudo ssr status
```

**成功的标志**（重点看这几行）：

```text
● ssr-native.service - ShadowsocksR Native Server
     Loaded: loaded (/etc/systemd/system/ssr-native.service; enabled)
     Active: active (running) since Mon 2026-01-01 12:00:00 UTC; 3 min ago
   Main PID: 12345 (ssr-server)
```

逐条对照：

| 看什么 | 正常的样子 | 不正常说明什么 |
| --- | --- | --- |
| `Loaded` 里有 `enabled` | `enabled` | 没有就说明没设开机自启，跑菜单 `3` 启动 |
| `Active` | `active (running)` | `failed` / `inactive` 说明没起来，去看菜单 `14` 的日志 |
| `Main PID` 有数字 | `12345 (ssr-server)` | 空的话服务根本没起来 |

再看端口有没有真的在监听（菜单 `23` 或手动）：

```bash
sudo ss -lntup | grep ssr
```

**成功标志**：能看到类似 `*:23456` 的监听地址和 `ssr-server` 进程。

---

<a id="七详细说明"></a>
## 七、详细说明

### 7.1 快捷命令（不进菜单也能用）

除了菜单，脚本还提供一批非交互命令，适合写进自动化脚本：

```bash
sudo ssr status     # 查看服务状态
sudo ssr start      # 启动
sudo ssr stop       # 停止
sudo ssr restart    # 重启
sudo ssr info       # 查看连接信息
sudo ssr link       # 生成 SSR 链接
sudo ssr logs       # 实时日志
sudo ssr env        # 系统环境检测
ssr --version       # 查看脚本版本
ssr --help          # 查看帮助
```

> 注意：`status` / `start` / `stop` / `restart` / `info` / `link` / `logs` / `env` 都需要 root 权限，所以要带 `sudo`。

<a id="72-手动安装方式推荐生产环境用这个"></a>
### 7.2 手动安装方式（推荐生产环境用这个）

生产服务器或对供应链安全有要求时，建议先下载、**读一遍源码**、检查语法，再运行：

```bash
# 1. 下载脚本到当前目录
wget https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh

# 2. 给执行权限
chmod +x ssr-v2-manager.sh

# 3. 语法检查（不会输出东西就是没问题）
bash -n ssr-v2-manager.sh

# 4. 看一眼版本号
./ssr-v2-manager.sh --version

# 5. 运行
sudo ./ssr-v2-manager.sh
```

只有 `curl` 的服务器：

```bash
curl -fsSL https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh -o /tmp/ssr-v2-manager.sh && sudo bash /tmp/ssr-v2-manager.sh
```

只有 `wget` 的服务器：

```bash
wget -qO /tmp/ssr-v2-manager.sh https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh && sudo bash /tmp/ssr-v2-manager.sh
```

首次运行后，管理器会被安装到：

```text
/usr/local/sbin/ssr-manager
```

并创建快捷命令：

```text
/usr/local/bin/ssr
```

以后直接 `sudo ssr` 就行。

### 7.3 从旧版本（V2.0.2 及更早）升级

V2.0.2 还没有「菜单 20 自更新管理脚本」的能力。老服务器需要**手动执行一次**：

```bash
curl -fsSL https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh -o /tmp/ssr-v2-manager.sh && sudo install -m 755 /tmp/ssr-v2-manager.sh /usr/local/sbin/ssr-manager && sudo ln -sfn /usr/local/sbin/ssr-manager /usr/local/bin/ssr && rm -f /tmp/ssr-v2-manager.sh
```

升到 V2.0.3 之后，以后直接 `sudo ssr` 选菜单 `20` 就能同时更新管理脚本和 SSR 服务端。

### 7.4 默认参数

快速安装（菜单 `1` → `1`）默认使用：

```text
端口：20000-50000 之间的随机未占用端口（极端情况下回退到 23456）
密码：32 位十六进制随机密码（openssl rand -hex 16）
加密：aes-128-ctr
协议：auth_aes128_md5
混淆：tls1.2_ticket_auth
UDP：开启
```

**所有核心参数都能在装完后通过菜单修改。**

> ⚠️ 记不住密码？不用记 —— 菜单 `7` 随时能看，菜单 `28` 能看完整 JSON，`config.json` 里也明文写着。

### 7.5 支持的加密方式 / 协议 / 混淆

这三样是 SSR 的核心参数，**客户端和服务端必须完全一致**，差一个字符就连不上。

**加密方式（菜单 `10`）** —— 负责内容加密：

| 编号 | 名称 | 说明 |
| --- | --- | --- |
| 1 | `aes-128-ctr` | **推荐 / 兼容性最好**，绝大多数客户端都支持 |
| 2 | `aes-192-ctr` | 更强一点，客户端支持度略低 |
| 3 | `aes-256-ctr` | 更强，客户端支持度略低 |
| 4 | `aes-128-cfb` | 老式流加密 |
| 5 | `aes-192-cfb` | 同上 |
| 6 | `aes-256-cfb` | 同上 |
| 7 | `chacha20` | 在手机 / ARM 设备上性能不错 |
| 8 | `chacha20-ietf` | chacha20 的标准版本 |
| 9 | `rc4-md5` | 很老的算法，**已经不安全**，仅特殊需求时用 |
| 10 | `none` | **不加密**，仅调试用，别在公网用 |

**协议（菜单 `11`）** —— 负责身份认证：

| 编号 | 名称 | 说明 |
| --- | --- | --- |
| 1 | `auth_aes128_md5` | **推荐 / 兼容性最好** |
| 2 | `auth_aes128_sha1` | 换哈希算法的认证协议 |
| 3 | `auth_chain_a` | 链式认证 A |
| 4 | `auth_chain_b` | 链式认证 B |
| 5 | `auth_sha1_v4` | SHA1 第四版 |
| 6 | `origin` | **不做额外认证**，只要密码对就连。兼容性最好但最不安全 |

**混淆（菜单 `12`）** —— 让流量看起来像「正常的 TLS / HTTP 流量」，而不是一眼就能识别的代理流量：

| 编号 | 名称 | 说明 |
| --- | --- | --- |
| 1 | `tls1.2_ticket_auth` | **推荐 / 兼容性最好**，伪装成 TLS 1.2 会话票据 |
| 2 | `tls1.2_ticket_fastauth` | 同上，更快的认证方式 |
| 3 | `http_simple` | 伪装成普通 HTTP GET |
| 4 | `http_post` | 伪装成 HTTP POST |
| 5 | `http_mix` | GET/POST 混合 |
| 6 | `plain` | **不混淆**，流量特征明显 |

> 加密 / 协议是否真的可用，取决于上游 ShadowsocksR-native 当前版本。

<a id="76-配置文件和文件位置"></a>
### 7.6 配置文件和文件位置

| 路径 | 是什么 |
| --- | --- |
| `/opt/shadowsocksr-native` | SSR 服务端源码目录（编译用） |
| `/usr/local/bin/ssr-server` | 编译出来的 SSR 服务端程序 |
| `/etc/ssr-native` | 配置目录 |
| `/etc/ssr-native/config.json` | **主配置文件**（端口、密码、加密、协议、混淆都在这） |
| `/etc/ssr-native/backups` | 配置备份目录（`config-<时间戳>.json`） |
| `/etc/systemd/system/ssr-native.service` | systemd 服务单元文件 |
| `/usr/local/sbin/ssr-manager` | 管理脚本本体 |
| `/usr/local/bin/ssr` | 快捷命令（软链接到上面那个） |
| `/usr/local/sbin/ssr-manager.bak` | 自更新前的旧版管理脚本备份 |
| `/etc/sysctl.d/99-ssr-bbr.conf` | BBR 配置 |
| `/etc/sysctl.d/99-ssr-network-tuning.conf` | 网络优化配置 |
| `/root/ssr-qrcode.png` | 菜单 `19` 生成的二维码图片 |

`config.json` 的权限被脚本设为 **600**（只有 root 能读写）。

systemd 服务的关键设置：

```ini
[Service]
Type=simple
ExecStart=/usr/local/bin/ssr-server -c /etc/ssr-native/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
```

意思是：崩了 3 秒后自动重启，文件句柄上限很高，不用 root 权限也能跑，临时文件目录独立。

### 7.7 BBR（菜单 `15` / `16`）

BBR 是 Linux 内核自带的 TCP 拥塞控制算法，**在丢包率高的线路上（比如跨境）能明显提升速度**。

菜单 `15` 会检测内核是否提供 BBR，然后写入：

```text
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
```

到 `/etc/sysctl.d/99-ssr-bbr.conf` 并立即生效。

菜单 `16` 查看状态：

```text
内核：5.15.0-119-generic
可用拥塞控制：reno cubic bbr
当前拥塞控制：bbr
默认队列算法：fq
tcp_bbr 模块：已加载
```

**如果当前拥塞控制不是 `bbr`**，脚本会提示「配置已写入，但当前未显示为 bbr；重启系统后再检查」—— 那就 `sudo reboot` 一下。

### 7.8 一键网络优化（菜单 `27`）

写一组**保守型** TCP 参数到 `/etc/sysctl.d/99-ssr-network-tuning.conf`：

```text
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_mtu_probing=1
```

**不会**改 DNS、**不会**改路由、**不会**动防火墙。

### 7.9 防火墙规则

脚本会自动处理**服务器操作系统内部**已经启用的防火墙：

| 防火墙 | 脚本行为 |
| --- | --- |
| UFW | `ufw allow <端口>/tcp` + `ufw allow <端口>/udp` |
| firewalld | `firewall-cmd --permanent --add-port=<端口>/tcp` + `/udp`，然后 reload |

**但脚本管不到云厂商控制台。** 见 [十、新手最常犯的 5 个错](#十新手最常犯的-5-个错)。

### 7.10 SSR 链接与二维码（菜单 `18` / `19`）

菜单 `18` 生成的链接长这样：

```text
ssr://base64编码的一长串
```

编码的内容是：`公网IP:端口:协议:加密:混淆:密码/?obfsparam=...&protoparam=...&remarks=...`

节点名称（`remarks`）会**自动带城市名**，格式是 `城市-IP-端口`，例如 `洛杉矶-1.2.3.4-23456`（只显示城市，不显示省份；直辖市显示市名）。

城市识别顺序（失败会依次兜底）：

1. `whois.pconline.com.cn`（太平洋电脑网，国内 IP 库）
2. `ipwho.is`（国际 IP 库）
3. `ipapi.co`（国际 IP 库）
4. 都失败就显示「节点」

菜单 `19` 会：

1. 在终端直接画 ANSI 二维码（**注意：终端不支持 ANSI 时可能显示成乱码**，这时直接看 PNG 文件）
2. 把 PNG 保存到 `/root/ssr-qrcode.png`

```bash
ls -l /root/ssr-qrcode.png
```

### 7.11 配置备份与恢复（菜单 `25` / `26`）

备份目录：

```text
/etc/ssr-native/backups
```

脚本在**修改重要参数前会自动备份**，所以你不用担心改坏了找不回。

菜单 `26` 会列出所有备份（按时间倒序）让你选：

```text
可用备份：
 1. /etc/ssr-native/backups/config-20260101-120000.json
 2. /etc/ssr-native/backups/config-20260102-093000.json
 0. 返回
请选择:
```

恢复后会：校验 JSON 有效性 → 复制回主配置 → 重设 600 权限 → 重开防火墙端口 → 重启服务。

### 7.12 看日志（菜单 `14`）

```bash
sudo journalctl -u ssr-native -f
```

或用菜单 `14`。退出实时日志按 `Ctrl+C`。

### 7.13 自更新机制（菜单 `20`）

这是本脚本比较特别的一点：**管理脚本自己也能更新自己**。

菜单 `20` 会依次做这些事：

1. 从本仓库 `main` 分支下载最新版 `ssr-v2-manager.sh`（带 `Cache-Control: no-cache` 和时间戳绕过缓存）
2. 检查下载内容第一行是不是 `#!/usr/bin/env bash`，不是就拒绝
3. 执行 `bash -n` 语法检查，**不通过就保留当前版本**
4. 对比 SHA256，一样就提示「已经是最新版本」
5. 旧脚本备份到 `/usr/local/sbin/ssr-manager.bak`
6. 写入 `.new` 临时文件后 `mv` 原子替换（**替换失败会尝试恢复旧版**）
7. 重建 `/usr/local/bin/ssr` 软链接
8. 然后才去更新 SSR 服务端：拉上游最新源码 → 重新编译 → 备份旧二进制 → 替换 → 重启
9. **如果新版本启动失败，自动把旧二进制恢复回去**

---

<a id="八目录结构"></a>
## 八、目录结构

本仓库只有 3 个文件，非常干净：

| 路径 | 类型 | 说明 |
| --- | --- | --- |
| `ssr-v2-manager.sh` | 文件（约 1200 行） | **脚本本体**，单文件包含了安装、管理、备份、更新等全部逻辑 |
| `README.md` | 文件 | 就是你正在看的这份说明 |
| `.gitignore` | 文件 | 忽略规则 |

`.gitignore` 内容：

```text
*.log
*.tmp
*.bak
ssr-qrcode.png
config.json
backups/
```

安装到服务器上之后，会额外多出这些东西（**不在本仓库里**，在服务器上）：

```text
/usr/local/sbin/ssr-manager          # 管理脚本本体
/usr/local/bin/ssr                   # 快捷命令
/usr/local/bin/ssr-server            # SSR 服务端程序
/etc/ssr-native/config.json          # 主配置
/etc/ssr-native/backups/             # 备份
/etc/systemd/system/ssr-native.service # systemd 单元
/opt/shadowsocksr-native/            # 源码
/etc/sysctl.d/99-ssr-bbr.conf         # BBR 配置
/etc/sysctl.d/99-ssr-network-tuning.conf # 网络优化配置
```

各路径的详细用途见 [7.6 配置文件和文件位置](#76-配置文件和文件位置)。

---

<a id="九常见问题排查"></a>
## 九、常见问题排查

| 现象 | 可能原因 | 怎么办 |
| --- | --- | --- |
| 一行命令没反应 / 提示 `command not found: curl` | 服务器没装 curl，且 wget 也不可用 | 先 `apt update && apt install -y curl wget`，再重试 |
| `无法识别操作系统` | 不是 Ubuntu / Debian | 脚本只支持这两种，换系统或用其他方案 |
| `当前脚本仅支持 Ubuntu / Debian，检测到：xxx` | 同上 | 同上 |
| `系统未使用 systemd` | 系统不是 systemd（精简镜像 / OpenWrt） | 换用带 systemd 的发行版 |
| 装完了但客户端连不上 | **云安全组没放行**（最常见） | 去云控制台放行 TCP + UDP 当前端口 |
| 装完了但客户端连不上 | 本机防火墙没放行 | 菜单 `17` 一键放行 |
| 装完了但客户端连不上 | 客户端参数和服务端对不上 | 菜单 `7` 逐项核对：端口/密码/加密/协议/混淆，**5 项必须全部一致** |
| 装完了但客户端连不上 | 客户端填的 IP 错了 | 菜单 `24` 看公网 IP，客户端必须填这个 |
| 装完了但客户端连不上 | 服务根本没起来 | `sudo ssr status` 看是不是 `active (running)`；不是就看菜单 `14` 日志 |
| 改端口后连不上了 | 云安全组还是老端口 | 脚本只能改本机防火墙，**云控制台要手动加新端口** |
| 改端口后连不上了 | 客户端还是老端口 | 客户端也要同步改 |
| 改了加密/协议/混淆后连不上 | 客户端没同步改 | 菜单 `7` 抄当前值，客户端改成一样 |
| `Active: failed` | 服务启动报错 | `sudo journalctl -u ssr-native -n 50 --no-pager` 看具体错误 |
| 编译失败 | 内存不够 / 缺依赖 / 连不上 GitHub | 先 `sudo ssr env` 看环境检测结果；内存 < 256MB 的加 swap；网络问题走代理或换源 |
| 编译失败 | 依赖装不上 | 菜单 `21`「重新编译安装（保留配置）」重试一次，它会补装依赖 |
| `GitHub连通 : 失败/超时` | 服务器连不上 GitHub | 换个网络环境，或先手动 `curl -I https://github.com` 排查 |
| 二维码显示成乱码 | 终端不支持 ANSI 彩色字符 | 直接看 `/root/ssr-qrcode.png`，或者用菜单 `18` 生成链接手动复制 |
| 生成链接时提示要输入 IP | 脚本没拿到公网 IP | 手动输入你的服务器 IP 或域名 |
| 节点名字显示「节点」而不是城市 | IP 库接口都访问失败 | 不影响使用，手动改备注名即可 |
| BBR 装完还是显示不是 bbr | 内核不支持，或需要重启 | `sudo reboot` 后再跑菜单 `16` |
| 菜单 `20` 说管理脚本已是最新 | 确实是最新版 | 属于正常提示，不是错误 |
| 菜单 `20` 提示语法检查失败 | 新版本脚本有问题 | 已自动保留当前版本，等上游修好再试 |
| 找不到 `ssr` 命令 | PATH 问题 | 用完整路径 `/usr/local/bin/ssr`，或 `export PATH=$PATH:/usr/local/bin` |
| 忘了密码 | —— | 菜单 `7` 或 `sudo ssr info` 直接看 |

---

<a id="十新手最常犯的-5-个错"></a>
## 十、新手最常犯的 5 个错

### ❌ 错误 1：忘了在云控制台放行端口

**这是 90% 的「装完连不上」的原因。**

脚本提示里已经写了：「云厂商控制台防火墙/安全组不受本脚本控制，请手动放行 TCP + UDP」。

**正确做法**：

```text
阿里云 / 腾讯云 / 华为云 → 控制台 → 安全组 → 入方向规则 → 添加规则
规则 1：协议 TCP，端口 23456，来源 0.0.0.0/0
规则 2：协议 UDP，端口 23456，来源 0.0.0.0/0
```

> ⚠️ 「来源 0.0.0.0/0」意味着全世界都能连这个端口。安全性更好的做法是**只放行你自己的 IP**，或者配合较强的随机密码。

### ❌ 错误 2：客户端的 5 个参数没和服务端对齐

SSR 客户端要填 **服务器地址、端口、密码、加密方式、协议、混淆插件**（密码 + 加密 + 协议 + 混淆 = 4 项，加地址端口共 6 项）。

**只要有一项对不上，就完全连不上，而且没有任何报错提示。**

**排查方法**：服务端跑 `sudo ssr info`，客户端拿这 4 个值逐个抄。

### ❌ 错误 3：混淆插件没装 / 没选

客户端里的「混淆插件」和「协议插件」必须和服务端**同名**。很多新手在客户端里选了 `tls1.2_ticket_auth` 的插件，服务端却是 `plain` —— 就连不上。

### ❌ 错误 4：改了服务端参数，忘了重启

脚本在菜单 `8`~`13` 里改完参数后**会自动重启**，一般不会出这个问题。但如果你**手动编辑了 `/etc/ssr-native/config.json`**，必须自己重启：

```bash
sudo ssr restart
```

### ❌ 错误 5：把密码和链接贴到公开的地方

`ssr://` 链接里明文包含密码。**不要**贴到 GitHub 仓库、截图发群里、或者发给不信任的人。

配置备份目录 `/etc/ssr-native/backups` 里也是明文密码，别整个目录打包上传。

---

<a id="十一安全注意事项"></a>
## 十一、安全注意事项

**应该做的：**

- ✅ 用随机强密码（快速安装默认就是 32 位随机十六进制）
- ✅ 云安全组**只放行实际需要的端口**，能指定具体 IP 就别写 `0.0.0.0/0`
- ✅ SSH 用密钥登录，并禁止 root 密码登录
- ✅ 定期 `sudo ssr env` 看一眼状态，定期翻 `journalctl` 查异常连接
- ✅ 定期 `sudo apt update && sudo apt upgrade` 打系统补丁
- ✅ 怀疑密码泄露了就跑菜单 `29` 重置配置（会生成新的随机端口和密码）

**不应该做的：**

- ❌ 不要把 `/etc/ssr-native/config.json` 或带密码的 `ssr://` 链接提交到公开 GitHub 仓库
- ❌ 不要把 `/root/ssr-qrcode.png` 二维码分享给不信任的人（扫一下就等于给你账号）
- ❌ 不要在公网用 `none`（不加密）或 `plain`（不混淆）
- ❌ 不要公开暴露 Redis、MySQL、数据库、其他管理面板等无关服务
- ❌ 不要用 `origin` 协议去做需要抗探测的场景

**关于一行安装命令的安全提示：**

那条 `tmp=$(mktemp) && curl ... | sudo bash` 会**从 `main` 分支下载脚本并以 root 权限运行**。这是所有一键安装脚本的通病。

如果你对供应链安全有要求，请走 [7.2 手动安装方式](#72-手动安装方式推荐生产环境用这个)：下载 → 读源码 → `bash -n` 语法检查 → 再运行。

**合规提醒**：请只在你拥有或获准管理的服务器和网络环境中使用，并遵守所在地法律法规、云服务商条款和网络管理要求。

---

<a id="十二卸载与回滚"></a>
## 十二、卸载与回滚

### 卸载 SSR 服务端

菜单选 `2`（卸载 SSR），确认后脚本会：

1. **自动备份当前配置**到 `/etc/ssr-native/backups`
2. `systemctl disable --now ssr-native` 停掉服务并取消开机自启
3. 从 UFW / firewalld 移除该端口的放行规则
4. 删除 `/etc/systemd/system/ssr-native.service`
5. 删除 `/usr/local/bin/ssr-server`
6. 删除 `/opt/shadowsocksr-native` 整个源码目录
7. 删除 `/etc/ssr-native/config.json`（**备份目录保留**）
8. `systemctl daemon-reload` + `reset-failed`

**管理脚本本身会保留**，所以卸载后你依然可以：

```bash
sudo ssr
```

随时重新安装。

### 手动彻底删除管理脚本

如果你连管理脚本也不要了：

```bash
sudo rm -f /usr/local/sbin/ssr-manager /usr/local/bin/ssr /usr/local/sbin/ssr-manager.bak
sudo rm -f /etc/sysctl.d/99-ssr-bbr.conf /etc/sysctl.d/99-ssr-network-tuning.conf
sudo rm -rf /etc/ssr-native
sudo systemctl daemon-reload
```

> ⚠️ `/etc/sysctl.d/99-ssr-network-tuning.conf` 和 `99-ssr-bbr.conf` 是系统级配置，删掉后 TCP 参数会回到默认值。**如果你自己手动调过这些参数，先备份再删。**

### 回滚配置

菜单 `26`（恢复配置）可以从备份目录里挑一个历史配置恢复，恢复后会自动重开防火墙端口并重启服务。

---

<a id="十三许可证与致谢"></a>
## 十三、许可证与致谢

### 上游项目

本仓库是**管理脚本**，不包含 SSR 服务端源码。安装时脚本会从上游仓库拉取源码并在服务器本地编译：

| 项目 | 地址 |
| --- | --- |
| ShadowsocksR-native（服务端源码） | https://github.com/ShadowsocksR-Live/shadowsocksr-native |
| 本仓库（管理脚本） | https://github.com/aiwozhonghua81/ssr-v2-manager |

### 注意事项

ShadowsocksR 属于**较老的协议栈**。上游项目的兼容性、协议实现和依赖可能发生变化，因此**建议在生产环境部署前，先在测试服务器上验证一遍**。

本脚本**不会**自动修改云厂商控制台的防火墙、安全组、备案或账号配置。

### 脚本自检

下载脚本后可以先做 Bash 语法检查：

```bash
bash -n ssr-v2-manager.sh
```

查看版本：

```bash
./ssr-v2-manager.sh --version
# 输出：SSR V2 Manager 2.0.3
```

### 当前版本

```text
SSR V2 Manager 2.0.3
```

---

如果这份说明帮到你了，欢迎点个 ⭐ Star。有问题去 [Issues](https://github.com/aiwozhonghua81/ssr-v2-manager/issues) 提。
