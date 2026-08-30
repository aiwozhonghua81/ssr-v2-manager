#!/usr/bin/env bash
set -uo pipefail

# ============================================================
# SSR V2 Manager
# ShadowsocksR-native interactive installer and management tool
# Target: Ubuntu 22.04/24.04, Debian 11/12/13 (systemd)
# ============================================================

SCRIPT_VERSION="2.0.3"
REPO_URL="https://github.com/ShadowsocksR-Live/shadowsocksr-native.git"
REPO_BRANCH="master"
SRC_DIR="/opt/shadowsocksr-native"
BIN_PATH="/usr/local/bin/ssr-server"
CONF_DIR="/etc/ssr-native"
CONF_FILE="${CONF_DIR}/config.json"
BACKUP_DIR="${CONF_DIR}/backups"
SERVICE_FILE="/etc/systemd/system/ssr-native.service"
SERVICE_NAME="ssr-native"
MANAGER_PATH="/usr/local/sbin/ssr-manager"
MANAGER_LINK="/usr/local/bin/ssr"
BBR_CONF="/etc/sysctl.d/99-ssr-bbr.conf"
TUNE_CONF="/etc/sysctl.d/99-ssr-network-tuning.conf"
MANAGER_RAW_URL="https://raw.githubusercontent.com/aiwozhonghua81/ssr-v2-manager/main/ssr-v2-manager.sh"

DEFAULT_METHOD="aes-128-ctr"
DEFAULT_PROTOCOL="auth_aes128_md5"
DEFAULT_OBFS="tls1.2_ticket_auth"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

log()  { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
info() { printf "${CYAN}[i]${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
err()  { printf "${RED}[-]${RESET} %s\n" "$*" >&2; }

need_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        err "请使用 root 权限运行：sudo bash $0"
        exit 1
    fi
}

press_enter() {
    echo
    read -r -p "按 Enter 返回菜单..." _ || true
}

confirm() {
    local prompt="${1:-确认继续？}"
    local ans
    read -r -p "${prompt} [y/N]: " ans || true
    [[ "${ans:-}" =~ ^[Yy]$ ]]
}

clear_screen() {
    if [[ -t 1 ]]; then
        clear 2>/dev/null || printf '\033c'
    fi
}

is_installed() {
    [[ -x "${BIN_PATH}" && -f "${CONF_FILE}" && -f "${SERVICE_FILE}" ]]
}

service_state() {
    if ! is_installed; then
        printf "未安装"
    elif systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        printf "运行中"
    else
        printf "已停止"
    fi
}

check_os() {
    [[ -r /etc/os-release ]] || { err "无法识别操作系统"; return 1; }
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        ubuntu|debian) ;;
        *) err "当前脚本仅支持 Ubuntu / Debian，检测到：${ID:-unknown}"; return 1 ;;
    esac
    command -v systemctl >/dev/null 2>&1 || { err "系统未使用 systemd"; return 1; }
    return 0
}

ensure_apt_tools() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y || return 1
    apt-get install -y --no-install-recommends \
        ca-certificates curl git openssl jq qrencode \
        build-essential gcc g++ gdb cmake make \
        autoconf automake libtool asciidoc xmlto iproute2 procps || return 1
    apt-get -f install -y || true
}

ensure_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        info "安装 jq..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y && apt-get install -y jq || {
            err "jq 安装失败"
            return 1
        }
    fi
}

random_port() {
    local p
    for _ in $(seq 1 100); do
        p="$(shuf -i 20000-50000 -n 1)"
        if ! ss -lntup 2>/dev/null | awk '{print $5}' | grep -Eq "[:.]${p}$"; then
            printf "%s" "${p}"
            return 0
        fi
    done
    printf "23456"
}

random_password() {
    openssl rand -hex 16 2>/dev/null || tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
}

validate_port() {
    local p="${1:-}"
    [[ "${p}" =~ ^[0-9]+$ ]] || return 1
    (( 10#${p} >= 1 && 10#${p} <= 65535 ))
}

port_in_use() {
    local p="$1"
    ss -lntup 2>/dev/null | awk '{print $5}' | grep -Eq "[:.]${p}$"
}

public_ip() {
    local ip=""
    ip="$(curl -4fsS --max-time 4 https://api.ipify.org 2>/dev/null || true)"
    [[ -n "${ip}" ]] || ip="$(curl -4fsS --max-time 4 https://ifconfig.me/ip 2>/dev/null || true)"
    [[ -n "${ip}" ]] || ip="$(curl -4fsS --max-time 4 https://icanhazip.com 2>/dev/null | tr -d '\r\n' || true)"
    [[ -n "${ip}" ]] || ip="<服务器公网IP>"
    printf "%s" "${ip}"
}

normalize_city_name() {
    local city="${1:-}" lower=""
    city="$(printf '%s' "${city}" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "${city}" && "${city}" != "null" ]] || { printf ""; return; }

    # 只保留城市名，不展示省份或行政区后缀。
    city="${city%特别行政区}"
    city="${city%自治州}"
    city="${city%地区}"
    city="${city%市}"

    lower="$(printf '%s' "${city}" | tr '[:upper:]' '[:lower:]')"
    case "${lower}" in
        beijing|"beijing city") city="北京" ;;
        shanghai|"shanghai city") city="上海" ;;
        hangzhou) city="杭州" ;;
        shenzhen) city="深圳" ;;
        guangzhou) city="广州" ;;
        qingdao) city="青岛" ;;
        chengdu) city="成都" ;;
        wuhan) city="武汉" ;;
        nanjing) city="南京" ;;
        fuzhou) city="福州" ;;
        heyuan) city="河源" ;;
        zhangjiakou) city="张家口" ;;
        hohhot|huhehaote) city="呼和浩特" ;;
        ulanqab|ulanchabu|wulanchabu) city="乌兰察布" ;;
        tianjin|"tianjin city") city="天津" ;;
        chongqing|"chongqing city") city="重庆" ;;
        xiamen) city="厦门" ;;
        suzhou) city="苏州" ;;
        ningbo) city="宁波" ;;
        hefei) city="合肥" ;;
        jinan) city="济南" ;;
        zhengzhou) city="郑州" ;;
        changsha) city="长沙" ;;
        nanchang) city="南昌" ;;
        xian|"xi'an") city="西安" ;;
        kunming) city="昆明" ;;
        guiyang) city="贵阳" ;;
        nanning) city="南宁" ;;
        haikou) city="海口" ;;
        shenyang) city="沈阳" ;;
        dalian) city="大连" ;;
        changchun) city="长春" ;;
        harbin) city="哈尔滨" ;;
        taiyuan) city="太原" ;;
        shijiazhuang) city="石家庄" ;;
        lanzhou) city="兰州" ;;
        yinchuan) city="银川" ;;
        xining) city="西宁" ;;
        urumqi|urumchi) city="乌鲁木齐" ;;
        lhasa) city="拉萨" ;;
        "hong kong") city="香港" ;;
        macao|macau) city="澳门" ;;
        taipei) city="台北" ;;
        kaohsiung) city="高雄" ;;
        singapore) city="新加坡" ;;
        tokyo) city="东京" ;;
        osaka) city="大阪" ;;
        seoul) city="首尔" ;;
        bangkok) city="曼谷" ;;
        "kuala lumpur") city="吉隆坡" ;;
        "los angeles") city="洛杉矶" ;;
        "san jose") city="圣何塞" ;;
        "san francisco") city="旧金山" ;;
        seattle) city="西雅图" ;;
        "new york"|"new york city") city="纽约" ;;
        london) city="伦敦" ;;
        frankfurt|"frankfurt am main") city="法兰克福" ;;
        paris) city="巴黎" ;;
        amsterdam) city="阿姆斯特丹" ;;
        sydney) city="悉尼" ;;
    esac
    printf "%s" "${city}"
}

server_city() {
    local ip="${1:-}" json="" city="" pro=""
    [[ -n "${ip}" && "${ip}" != "<服务器公网IP>" ]] || { printf "节点"; return; }

    # 首选中文 IP 库，只读取 city；直辖市 city 为空时才回退到同级 pro。
    json="$(curl -4fsSL --max-time 5 -A 'Mozilla/5.0'         "https://whois.pconline.com.cn/ipJson.jsp?ip=${ip}&json=true" 2>/dev/null || true)"
    if [[ -n "${json}" ]]; then
        city="$(printf '%s' "${json}" | jq -r '.city // empty' 2>/dev/null || true)"
        pro="$(printf '%s' "${json}" | jq -r '.pro // empty' 2>/dev/null || true)"
        if [[ -z "${city}" && ( "${pro}" == *市 || "${pro}" == *特别行政区 ) ]]; then
            city="${pro}"
        fi
    fi

    # HTTPS 国际 IP 库兜底。
    if [[ -z "${city}" ]]; then
        json="$(curl -4fsSL --max-time 5 "https://ipwho.is/${ip}" 2>/dev/null || true)"
        [[ -n "${json}" ]] && city="$(printf '%s' "${json}" | jq -r 'select(.success != false) | .city // empty' 2>/dev/null || true)"
    fi
    if [[ -z "${city}" ]]; then
        city="$(curl -4fsSL --max-time 5 "https://ipapi.co/${ip}/city/" 2>/dev/null | tr -d '\r\n' || true)"
    fi

    city="$(normalize_city_name "${city}")"
    [[ -n "${city}" ]] || city="节点"
    printf "%s" "${city}"
}

cfg_get() {
    local filter="$1"
    if command -v jq >/dev/null 2>&1 && [[ -f "${CONF_FILE}" ]]; then
        jq -r "${filter} // empty" "${CONF_FILE}" 2>/dev/null
    fi
}

current_port()     { cfg_get '.server_settings.listen_port'; }
current_password() { cfg_get '.password'; }
current_method()   { cfg_get '.method'; }
current_protocol() { cfg_get '.protocol'; }
current_obfs()     { cfg_get '.obfs'; }
current_udp()      { cfg_get '.udp'; }

backup_config_quiet() {
    [[ -f "${CONF_FILE}" ]] || return 0
    mkdir -p "${BACKUP_DIR}"
    local f="${BACKUP_DIR}/config-$(date +%Y%m%d-%H%M%S).json"
    cp -a "${CONF_FILE}" "${f}"
    printf "%s" "${f}"
}

write_config() {
    local port="$1" password="$2" method="$3" protocol="$4" obfs="$5" udp="$6"
    ensure_jq || return 1
    mkdir -p "${CONF_DIR}" "${BACKUP_DIR}"

    jq -n \
        --arg password "${password}" \
        --arg method "${method}" \
        --arg protocol "${protocol}" \
        --arg obfs "${obfs}" \
        --argjson port "${port}" \
        --argjson udp "${udp}" \
        '{
          password: $password,
          method: $method,
          protocol: $protocol,
          protocol_param: "",
          obfs: $obfs,
          obfs_param: "",
          udp: $udp,
          idle_timeout: 300,
          connect_timeout: 6,
          udp_timeout: 6,
          server_settings: {
            listen_address: "0.0.0.0",
            listen_port: $port
          },
          client_settings: {
            server: "127.0.0.1",
            server_port: $port,
            listen_address: "127.0.0.1",
            listen_port: 1080
          },
          over_tls_settings: {
            enable: false,
            server_domain: "",
            path: "/",
            root_cert_file: ""
          }
        }' > "${CONF_FILE}" || return 1

    chmod 600 "${CONF_FILE}"
}

write_service() {
    cat > "${SERVICE_FILE}" <<EOF_SERVICE
[Unit]
Description=ShadowsocksR Native Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BIN_PATH} -c ${CONF_FILE}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF_SERVICE
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}" >/dev/null 2>&1 || true
}

build_ssr_fresh() {
    rm -rf "${SRC_DIR}"
    log "下载 ShadowsocksR-native 源码..."
    if ! git clone --recursive --branch "${REPO_BRANCH}" "${REPO_URL}" "${SRC_DIR}"; then
        err "源码下载失败"
        return 1
    fi
    build_ssr_existing
}

build_ssr_existing() {
    [[ -d "${SRC_DIR}" ]] || return 1
    log "编译 ShadowsocksR-native..."
    git -C "${SRC_DIR}" submodule update --init --recursive || true
    rm -rf "${SRC_DIR}/build"
    mkdir -p "${SRC_DIR}/build"
    (
        cd "${SRC_DIR}/build" || exit 1
        cmake .. && make -j"$(nproc)"
    ) || {
        err "编译失败"
        return 1
    }
    [[ -x "${SRC_DIR}/build/src/ssr-server" ]] || {
        err "编译完成但未找到 ssr-server"
        return 1
    }
    install -m 0755 "${SRC_DIR}/build/src/ssr-server" "${BIN_PATH}"
}

open_firewall_port() {
    local p="$1"
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
        ufw allow "${p}/tcp" >/dev/null 2>&1 || true
        ufw allow "${p}/udp" >/dev/null 2>&1 || true
        log "UFW 已放行 ${p}/TCP + UDP"
    fi
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --add-port="${p}/tcp" >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-port="${p}/udp" >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
        log "firewalld 已放行 ${p}/TCP + UDP"
    fi
}

remove_firewall_port() {
    local p="$1"
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
        ufw delete allow "${p}/tcp" >/dev/null 2>&1 || true
        ufw delete allow "${p}/udp" >/dev/null 2>&1 || true
    fi
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --remove-port="${p}/tcp" >/dev/null 2>&1 || true
        firewall-cmd --permanent --remove-port="${p}/udp" >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    fi
}

restart_and_check() {
    systemctl daemon-reload
    systemctl restart "${SERVICE_NAME}" || true
    sleep 1
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        log "SSR 已重新启动"
        return 0
    fi
    err "SSR 启动失败"
    journalctl -u "${SERVICE_NAME}" --no-pager -n 40 2>/dev/null || true
    return 1
}

choose_method() {
    echo
    echo "请选择加密方式："
    echo " 1. aes-128-ctr        [推荐/兼容]"
    echo " 2. aes-192-ctr"
    echo " 3. aes-256-ctr"
    echo " 4. aes-128-cfb"
    echo " 5. aes-192-cfb"
    echo " 6. aes-256-cfb"
    echo " 7. chacha20"
    echo " 8. chacha20-ietf"
    echo " 9. rc4-md5"
    echo "10. none"
    read -r -p "输入数字 [默认 1]: " n || true
    case "${n:-1}" in
        1) CHOICE_VALUE="aes-128-ctr" ;;
        2) CHOICE_VALUE="aes-192-ctr" ;;
        3) CHOICE_VALUE="aes-256-ctr" ;;
        4) CHOICE_VALUE="aes-128-cfb" ;;
        5) CHOICE_VALUE="aes-192-cfb" ;;
        6) CHOICE_VALUE="aes-256-cfb" ;;
        7) CHOICE_VALUE="chacha20" ;;
        8) CHOICE_VALUE="chacha20-ietf" ;;
        9) CHOICE_VALUE="rc4-md5" ;;
        10) CHOICE_VALUE="none" ;;
        *) warn "无效选择，使用 ${DEFAULT_METHOD}"; CHOICE_VALUE="${DEFAULT_METHOD}" ;;
    esac
}

choose_protocol() {
    echo
    echo "请选择协议："
    echo "1. auth_aes128_md5    [推荐/兼容]"
    echo "2. auth_aes128_sha1"
    echo "3. auth_chain_a"
    echo "4. auth_chain_b"
    echo "5. auth_sha1_v4"
    echo "6. origin"
    read -r -p "输入数字 [默认 1]: " n || true
    case "${n:-1}" in
        1) CHOICE_VALUE="auth_aes128_md5" ;;
        2) CHOICE_VALUE="auth_aes128_sha1" ;;
        3) CHOICE_VALUE="auth_chain_a" ;;
        4) CHOICE_VALUE="auth_chain_b" ;;
        5) CHOICE_VALUE="auth_sha1_v4" ;;
        6) CHOICE_VALUE="origin" ;;
        *) warn "无效选择，使用 ${DEFAULT_PROTOCOL}"; CHOICE_VALUE="${DEFAULT_PROTOCOL}" ;;
    esac
}

choose_obfs() {
    echo
    echo "请选择混淆："
    echo "1. tls1.2_ticket_auth       [推荐/兼容]"
    echo "2. tls1.2_ticket_fastauth"
    echo "3. http_simple"
    echo "4. http_post"
    echo "5. http_mix"
    echo "6. plain"
    read -r -p "输入数字 [默认 1]: " n || true
    case "${n:-1}" in
        1) CHOICE_VALUE="tls1.2_ticket_auth" ;;
        2) CHOICE_VALUE="tls1.2_ticket_fastauth" ;;
        3) CHOICE_VALUE="http_simple" ;;
        4) CHOICE_VALUE="http_post" ;;
        5) CHOICE_VALUE="http_mix" ;;
        6) CHOICE_VALUE="plain" ;;
        *) warn "无效选择，使用 ${DEFAULT_OBFS}"; CHOICE_VALUE="${DEFAULT_OBFS}" ;;
    esac
}

install_ssr() {
    if is_installed; then
        warn "SSR 已安装。"
        return 0
    fi
    check_os || return 1

    echo
    echo "1. 快速安装（随机端口 + 随机密码 + 推荐参数）"
    echo "2. 自定义安装"
    echo "0. 返回"
    read -r -p "请选择: " mode || true
    [[ "${mode:-}" != "0" ]] || return 0

    local port password method protocol obfs udp="true"
    port="$(random_port)"
    password="$(random_password)"
    method="${DEFAULT_METHOD}"
    protocol="${DEFAULT_PROTOCOL}"
    obfs="${DEFAULT_OBFS}"

    if [[ "${mode:-1}" == "2" ]]; then
        local p pass udp_ans
        read -r -p "端口 [默认随机 ${port}]: " p || true
        if [[ -n "${p:-}" ]]; then
            if ! validate_port "${p}"; then
                err "端口必须为 1-65535 的数字"
                return 1
            fi
            if port_in_use "${p}"; then
                err "端口 ${p} 已被占用"
                return 1
            fi
            port="${p}"
        fi
        read -r -p "密码 [直接回车自动生成]: " pass || true
        [[ -n "${pass:-}" ]] && password="${pass}"

        choose_method; method="${CHOICE_VALUE}"
        choose_protocol; protocol="${CHOICE_VALUE}"
        choose_obfs; obfs="${CHOICE_VALUE}"
        read -r -p "开启 UDP？[Y/n]: " udp_ans || true
        [[ "${udp_ans:-}" =~ ^[Nn]$ ]] && udp="false"
    fi

    echo
    info "即将安装：端口=${port}，加密=${method}，协议=${protocol}，混淆=${obfs}，UDP=${udp}"
    confirm "确认开始安装？" || return 0

    ensure_apt_tools || return 1
    build_ssr_fresh || return 1
    write_config "${port}" "${password}" "${method}" "${protocol}" "${obfs}" "${udp}" || return 1
    write_service
    open_firewall_port "${port}"
    restart_and_check || return 1
    log "SSR 安装完成"
    show_info
}

uninstall_ssr() {
    if ! is_installed; then
        warn "SSR 当前未安装"
        return 0
    fi
    local p
    p="$(current_port)"
    warn "此操作将删除 SSR 服务、二进制、源码和当前配置。管理脚本 ssr 会保留。"
    confirm "确认卸载 SSR？" || return 0

    local bk
    bk="$(backup_config_quiet)"
    [[ -n "${bk}" ]] && info "卸载前配置已备份：${bk}"
    systemctl disable --now "${SERVICE_NAME}" >/dev/null 2>&1 || true
    remove_firewall_port "${p}"
    rm -f "${SERVICE_FILE}" "${BIN_PATH}"
    rm -rf "${SRC_DIR}"
    # Preserve backups, remove active config only.
    rm -f "${CONF_FILE}"
    systemctl daemon-reload
    systemctl reset-failed >/dev/null 2>&1 || true
    log "SSR 已卸载。备份目录如存在则保留：${BACKUP_DIR}"
}

start_ssr() {
    is_installed || { warn "SSR 未安装"; return; }
    systemctl start "${SERVICE_NAME}" && log "SSR 已启动"
}

stop_ssr() {
    is_installed || { warn "SSR 未安装"; return; }
    systemctl stop "${SERVICE_NAME}" && log "SSR 已停止"
}

restart_ssr() {
    is_installed || { warn "SSR 未安装"; return; }
    restart_and_check
}

status_ssr() {
    if ! is_installed; then
        warn "SSR 未安装"
        return
    fi
    systemctl status "${SERVICE_NAME}" --no-pager -l || true
}

show_info() {
    is_installed || { warn "SSR 未安装"; return; }
    ensure_jq || return
    local ip city node_name port password method protocol obfs udp state
    ip="$(public_ip)"
    city="$(server_city "${ip}")"
    port="$(current_port)"
    node_name="${city}-${ip}-${port}"
    password="$(current_password)"
    method="$(current_method)"
    protocol="$(current_protocol)"
    obfs="$(current_obfs)"
    udp="$(current_udp)"
    state="$(service_state)"

    cat <<INFO

================ SSR 连接信息 ================
状态       : ${state}
节点名称   : ${node_name}
城市       : ${city}
服务器     : ${ip}
端口       : ${port}
密码       : ${password}
加密       : ${method}
协议       : ${protocol}
混淆       : ${obfs}
UDP        : ${udp}
配置文件   : ${CONF_FILE}
===============================================

云服务器控制台还需要放行：
  TCP ${port}
  UDP ${port}

以后直接输入：ssr
INFO
}

change_port() {
    is_installed || { warn "SSR 未安装"; return; }
    ensure_jq || return
    local old new tmp
    old="$(current_port)"
    echo "当前端口：${old}"
    read -r -p "请输入新端口: " new || true
    validate_port "${new:-}" || { err "端口必须为 1-65535 的数字"; return; }
    [[ "${new}" != "${old}" ]] || { warn "新旧端口相同"; return; }
    if port_in_use "${new}"; then
        err "端口 ${new} 已被其他程序占用"
        return
    fi
    backup_config_quiet >/dev/null
    tmp="$(mktemp)"
    jq --argjson p "${new}" '.server_settings.listen_port=$p | .client_settings.server_port=$p' "${CONF_FILE}" > "${tmp}" && mv "${tmp}" "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
    open_firewall_port "${new}"
    restart_and_check && {
        remove_firewall_port "${old}"
        log "端口已修改：${old} -> ${new}"
        warn "如使用阿里云/腾讯云等，请同时在云防火墙/安全组放行 ${new}/TCP 和 UDP。"
    }
}

change_password() {
    is_installed || { warn "SSR 未安装"; return; }
    ensure_jq || return
    local mode pass tmp
    echo "1. 手动输入密码"
    echo "2. 自动生成随机密码"
    echo "0. 返回"
    read -r -p "请选择: " mode || true
    case "${mode:-0}" in
        1)
            read -r -p "请输入新密码: " pass || true
            [[ -n "${pass:-}" ]] || { err "密码不能为空"; return; }
            ;;
        2) pass="$(random_password)" ;;
        *) return ;;
    esac
    backup_config_quiet >/dev/null
    tmp="$(mktemp)"
    jq --arg v "${pass}" '.password=$v' "${CONF_FILE}" > "${tmp}" && mv "${tmp}" "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
    restart_and_check && log "密码已修改为：${pass}"
}

change_method() {
    is_installed || { warn "SSR 未安装"; return; }
    ensure_jq || return
    local old tmp
    old="$(current_method)"
    echo "当前加密：${old}"
    choose_method
    backup_config_quiet >/dev/null
    tmp="$(mktemp)"
    jq --arg v "${CHOICE_VALUE}" '.method=$v' "${CONF_FILE}" > "${tmp}" && mv "${tmp}" "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
    restart_and_check && log "加密方式已修改：${old} -> ${CHOICE_VALUE}"
}

change_protocol() {
    is_installed || { warn "SSR 未安装"; return; }
    ensure_jq || return
    local old tmp
    old="$(current_protocol)"
    echo "当前协议：${old}"
    choose_protocol
    backup_config_quiet >/dev/null
    tmp="$(mktemp)"
    jq --arg v "${CHOICE_VALUE}" '.protocol=$v' "${CONF_FILE}" > "${tmp}" && mv "${tmp}" "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
    restart_and_check && log "协议已修改：${old} -> ${CHOICE_VALUE}"
}

change_obfs() {
    is_installed || { warn "SSR 未安装"; return; }
    ensure_jq || return
    local old tmp
    old="$(current_obfs)"
    echo "当前混淆：${old}"
    choose_obfs
    backup_config_quiet >/dev/null
    tmp="$(mktemp)"
    jq --arg v "${CHOICE_VALUE}" '.obfs=$v' "${CONF_FILE}" > "${tmp}" && mv "${tmp}" "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
    restart_and_check && log "混淆已修改：${old} -> ${CHOICE_VALUE}"
}

toggle_udp() {
    is_installed || { warn "SSR 未安装"; return; }
    ensure_jq || return
    local old new tmp
    old="$(current_udp)"
    [[ "${old}" == "true" ]] && new="false" || new="true"
    backup_config_quiet >/dev/null
    tmp="$(mktemp)"
    jq --argjson v "${new}" '.udp=$v' "${CONF_FILE}" > "${tmp}" && mv "${tmp}" "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
    restart_and_check && log "UDP 已切换：${old} -> ${new}"
}

show_logs() {
    is_installed || { warn "SSR 未安装"; return; }
    echo "按 Ctrl+C 退出实时日志。"
    sleep 1
    journalctl -u "${SERVICE_NAME}" -f --no-pager || true
}

enable_bbr() {
    local available
    available="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
    if ! grep -qw bbr <<<"${available}"; then
        modprobe tcp_bbr 2>/dev/null || true
        available="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
    fi
    if ! grep -qw bbr <<<"${available}"; then
        err "当前内核没有提供 BBR。请确认内核版本。"
        return
    fi
    cat > "${BBR_CONF}" <<'EOF_BBR'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF_BBR
    sysctl --system >/dev/null 2>&1 || true
    if [[ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)" == "bbr" ]]; then
        log "BBR 已启用"
    else
        warn "配置已写入，但当前未显示为 bbr；重启系统后再检查。"
    fi
}

show_bbr() {
    echo "内核：$(uname -r)"
    echo "可用拥塞控制：$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo unknown)"
    echo "当前拥塞控制：$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
    echo "默认队列算法：$(sysctl -n net.core.default_qdisc 2>/dev/null || echo unknown)"
    if lsmod 2>/dev/null | grep -q '^tcp_bbr'; then
        echo "tcp_bbr 模块：已加载"
    else
        echo "tcp_bbr 模块：未显示为独立模块（可能内建内核）"
    fi
}

firewall_current_port() {
    is_installed || { warn "SSR 未安装"; return; }
    local p
    p="$(current_port)"
    open_firewall_port "${p}"
    info "当前 SSR 端口：${p}"
    warn "云厂商控制台防火墙/安全组不受本脚本控制，请手动放行 TCP + UDP ${p}。"
}

b64url() {
    printf '%s' "$1" | base64 -w 0 | tr '+/' '-_' | tr -d '='
}

generate_ssr_link() {
    is_installed || { warn "SSR 未安装"; return 1; }
    ensure_jq || return 1
    local host city port password method protocol obfs pparam oparam remarks pass64 raw query
    host="$(public_ip)"
    [[ "${host}" != "<服务器公网IP>" ]] || {
        read -r -p "未自动获取公网 IP，请输入服务器公网 IP/域名: " host || true
        [[ -n "${host:-}" ]] || return 1
    }
    port="$(current_port)"
    password="$(current_password)"
    method="$(current_method)"
    protocol="$(current_protocol)"
    obfs="$(current_obfs)"
    pparam="$(cfg_get '.protocol_param')"
    oparam="$(cfg_get '.obfs_param')"
    city="$(server_city "${host}")"
    remarks="${city}-${host}-${port}"
    info "节点名称：${remarks}"
    pass64="$(b64url "${password}")"
    query="obfsparam=$(b64url "${oparam}")&protoparam=$(b64url "${pparam}")&remarks=$(b64url "${remarks}")"
    raw="${host}:${port}:${protocol}:${method}:${obfs}:${pass64}/?${query}"
    SSR_LINK="ssr://$(b64url "${raw}")"
    echo
    echo "${SSR_LINK}"
}

show_qrcode() {
    generate_ssr_link || return
    if ! command -v qrencode >/dev/null 2>&1; then
        info "安装 qrencode..."
        apt-get update -y && apt-get install -y qrencode || return
    fi
    echo
    qrencode -t ANSIUTF8 "${SSR_LINK}" || true
    local out="/root/ssr-qrcode.png"
    qrencode -o "${out}" -s 8 "${SSR_LINK}" && info "二维码 PNG 已保存到服务器：${out}"
}

update_manager_script() {
    local tmp backup new_version old_hash new_hash downloaded=false
    tmp="$(mktemp)"
    backup="${MANAGER_PATH}.bak"

    info "检查并下载最新版 SSR V2 Manager..."
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL --connect-timeout 8 --max-time 30 \
            -H 'Cache-Control: no-cache' \
            "${MANAGER_RAW_URL}?t=$(date +%s)" -o "${tmp}"; then
            downloaded=true
        fi
    fi
    if [[ "${downloaded}" != "true" ]] && command -v wget >/dev/null 2>&1; then
        if wget -q --timeout=30 -O "${tmp}" "${MANAGER_RAW_URL}?t=$(date +%s)"; then
            downloaded=true
        fi
    fi
    if [[ "${downloaded}" != "true" ]]; then
        rm -f "${tmp}"
        err "管理脚本下载失败，请检查 GitHub 网络连接。"
        return 1
    fi

    if [[ ! -s "${tmp}" ]] || ! head -n 1 "${tmp}" | grep -q '^#!/usr/bin/env bash'; then
        rm -f "${tmp}"
        err "下载内容不是有效的 SSR 管理脚本。"
        return 1
    fi
    if ! bash -n "${tmp}"; then
        rm -f "${tmp}"
        err "新版管理脚本 Bash 语法检查失败，已保留当前版本。"
        return 1
    fi

    new_version="$(grep -m1 '^SCRIPT_VERSION=' "${tmp}" | sed -E 's/^SCRIPT_VERSION="([^"]+)".*/\1/' || true)"
    old_hash="$(sha256sum "${MANAGER_PATH}" 2>/dev/null | awk '{print $1}' || true)"
    new_hash="$(sha256sum "${tmp}" 2>/dev/null | awk '{print $1}' || true)"

    if [[ -n "${old_hash}" && "${old_hash}" == "${new_hash}" ]]; then
        rm -f "${tmp}"
        ln -sfn "${MANAGER_PATH}" "${MANAGER_LINK}" 2>/dev/null || true
        info "管理脚本已经是最新版本：${new_version:-${SCRIPT_VERSION}}"
        return 0
    fi

    if [[ -f "${MANAGER_PATH}" ]]; then
        cp -a "${MANAGER_PATH}" "${backup}" || {
            rm -f "${tmp}"
            err "无法备份当前管理脚本。"
            return 1
        }
    fi

    if ! install -m 755 "${tmp}" "${MANAGER_PATH}.new"; then
        rm -f "${tmp}" "${MANAGER_PATH}.new"
        err "新版管理脚本写入失败。"
        return 1
    fi
    if ! mv -f "${MANAGER_PATH}.new" "${MANAGER_PATH}"; then
        [[ -f "${backup}" ]] && cp -a "${backup}" "${MANAGER_PATH}" 2>/dev/null || true
        rm -f "${tmp}" "${MANAGER_PATH}.new"
        err "管理脚本替换失败，已尝试恢复旧版本。"
        return 1
    fi

    chmod 755 "${MANAGER_PATH}"
    ln -sfn "${MANAGER_PATH}" "${MANAGER_LINK}"
    rm -f "${tmp}"
    log "管理脚本已更新：${SCRIPT_VERSION} -> ${new_version:-latest}"
    info "下次执行 sudo ssr 时将使用新版管理脚本。"
    return 0
}

update_ssr() {
    warn "此操作将同时更新：1) SSR V2 管理脚本；2) ShadowsocksR-native 源码/程序。"
    confirm "继续执行完整更新？" || return

    local manager_ok=false oldbin=""
    if update_manager_script; then
        manager_ok=true
    else
        warn "管理脚本更新失败，将继续尝试更新 SSR 服务端。"
    fi

    if ! is_installed; then
        warn "SSR 服务端尚未安装，已跳过 ShadowsocksR-native 更新。"
        [[ "${manager_ok}" == "true" ]] && log "管理脚本更新完成。"
        return
    fi

    ensure_apt_tools || {
        err "依赖安装/检查失败，SSR 服务端未更新。"
        return
    }

    oldbin="${BIN_PATH}.bak.$(date +%s)"
    cp -a "${BIN_PATH}" "${oldbin}" || true

    if [[ -d "${SRC_DIR}/.git" ]]; then
        git -C "${SRC_DIR}" fetch origin "${REPO_BRANCH}" || { err "Git fetch 失败"; return; }
        git -C "${SRC_DIR}" reset --hard "origin/${REPO_BRANCH}" || { err "Git reset 失败"; return; }
        git -C "${SRC_DIR}" submodule update --init --recursive || true
        build_ssr_existing || {
            cp -a "${oldbin}" "${BIN_PATH}" 2>/dev/null || true
            err "SSR 编译失败，已保留/恢复旧二进制。"
            return
        }
    else
        build_ssr_fresh || {
            cp -a "${oldbin}" "${BIN_PATH}" 2>/dev/null || true
            err "SSR 下载或编译失败，已保留/恢复旧二进制。"
            return
        }
    fi

    if restart_and_check; then
        rm -f "${oldbin}"
        log "ShadowsocksR-native 更新完成。"
    else
        warn "新版本 SSR 启动失败，恢复旧二进制。"
        cp -a "${oldbin}" "${BIN_PATH}" 2>/dev/null || true
        restart_and_check || true
    fi

    if [[ "${manager_ok}" == "true" ]]; then
        log "完整更新完成：管理脚本 + SSR 服务端。"
    else
        warn "SSR 服务端已处理，但管理脚本未更新成功，请稍后重试菜单 20。"
    fi
}

reinstall_binary() {
    is_installed || { warn "SSR 未安装，请使用安装菜单"; return; }
    confirm "重新编译安装 SSR，并保留当前配置？" || return
    ensure_apt_tools || return
    systemctl stop "${SERVICE_NAME}" || true
    build_ssr_fresh || { restart_and_check || true; return; }
    write_service
    restart_and_check && log "重新安装完成，原配置已保留"
}

environment_check() {
    echo "================ 系统环境检测 ================"
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        echo "系统       : ${PRETTY_NAME:-unknown}"
    fi
    echo "架构       : $(uname -m)"
    echo "内核       : $(uname -r)"
    echo "CPU 核心   : $(nproc 2>/dev/null || echo unknown)"
    if command -v free >/dev/null 2>&1; then
        echo "内存       : $(free -h | awk '/Mem:/ {print $2 " total / " $3 " used"}')"
    fi
    echo "根分区     : $(df -h / | awk 'NR==2 {print $2 " total / " $3 " used / " $4 " free"}')"
    echo "公网 IPv4  : $(public_ip)"
    echo "systemd    : $(systemctl --version 2>/dev/null | head -n1 || echo unavailable)"
    echo "SSR 状态   : $(service_state)"
    echo "BBR        : $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
    echo -n "GitHub连通 : "
    if curl -fsSI --max-time 6 https://github.com >/dev/null 2>&1; then echo "正常"; else echo "失败/超时"; fi
    echo "================================================"
}

show_listening_port() {
    if is_installed; then
        local p
        p="$(current_port)"
        echo "SSR 配置端口：${p}"
        echo
        ss -lntup 2>/dev/null | { head -n1; grep -E "[:.]${p}[[:space:]]|ssr-server" || true; }
    else
        warn "SSR 未安装"
        ss -lntup 2>/dev/null | head -n 30 || true
    fi
}

show_public_ip() {
    local ip city
    ip="$(public_ip)"
    city="$(server_city "${ip}")"
    echo "公网 IPv4：${ip}"
    echo "所在城市：${city}"
    echo "本机地址："
    ip -br addr show 2>/dev/null || true
}

backup_config() {
    is_installed || { warn "SSR 未安装"; return; }
    local f
    f="$(backup_config_quiet)"
    log "配置已备份：${f}"
}

restore_config() {
    ensure_jq || return
    mkdir -p "${BACKUP_DIR}"
    local files=()
    mapfile -t files < <(find "${BACKUP_DIR}" -maxdepth 1 -type f -name 'config-*.json' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{print $2}')
    if (( ${#files[@]} == 0 )); then
        warn "没有找到配置备份"
        return
    fi
    echo "可用备份："
    local i
    for i in "${!files[@]}"; do
        printf "%2d. %s\n" "$((i+1))" "${files[$i]}"
    done
    echo " 0. 返回"
    local n
    read -r -p "请选择: " n || true
    [[ "${n:-0}" =~ ^[0-9]+$ ]] || return
    (( n >= 1 && n <= ${#files[@]} )) || return
    local src="${files[$((n-1))]}"
    jq empty "${src}" >/dev/null 2>&1 || { err "备份 JSON 无效"; return; }
    [[ -f "${CONF_FILE}" ]] && backup_config_quiet >/dev/null
    cp -a "${src}" "${CONF_FILE}"
    chmod 600 "${CONF_FILE}"
    if [[ -x "${BIN_PATH}" && -f "${SERVICE_FILE}" ]]; then
        open_firewall_port "$(current_port)"
        restart_and_check || true
    fi
    log "配置已恢复：${src}"
}

network_tuning() {
    warn "此选项应用保守型 Linux TCP 参数，不会修改 DNS、路由或防火墙。"
    confirm "确认应用通用网络优化？" || return
    cat > "${TUNE_CONF}" <<'EOF_TUNE'
# Conservative TCP/network tuning for a small proxy server.
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_mtu_probing=1
EOF_TUNE
    sysctl --system >/dev/null 2>&1 || true
    log "网络优化配置已应用：${TUNE_CONF}"
}

show_full_config() {
    is_installed || { warn "SSR 未安装"; return; }
    ensure_jq || return
    echo "配置文件：${CONF_FILE}"
    jq . "${CONF_FILE}"
}

reset_config() {
    is_installed || { warn "SSR 未安装"; return; }
    warn "将生成新的随机端口和密码，并恢复推荐的加密/协议/混淆参数。"
    confirm "确认重置 SSR 配置？" || return
    local old newp newpass
    old="$(current_port)"
    newp="$(random_port)"
    newpass="$(random_password)"
    backup_config_quiet >/dev/null
    write_config "${newp}" "${newpass}" "${DEFAULT_METHOD}" "${DEFAULT_PROTOCOL}" "${DEFAULT_OBFS}" "true" || return
    open_firewall_port "${newp}"
    if restart_and_check; then
        remove_firewall_port "${old}"
        log "SSR 配置已重置"
        show_info
    fi
}

install_manager_command() {
    need_root
    local self
    self="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
    if [[ "${self}" != "${MANAGER_PATH}" && -f "${self}" ]]; then
        install -m 0755 "${self}" "${MANAGER_PATH}" 2>/dev/null || true
    fi
    if [[ -f "${MANAGER_PATH}" ]]; then
        ln -sfn "${MANAGER_PATH}" "${MANAGER_LINK}" 2>/dev/null || true
    fi
}

show_menu() {
    local state ip="-" port="-"
    state="$(service_state)"
    if is_installed && command -v jq >/dev/null 2>&1; then
        port="$(current_port)"
    fi

    clear_screen
    printf "${BOLD}${CYAN}============================================================${RESET}\n"
    printf "${BOLD}              SSR V2 一键安装 / 管理脚本 v%s${RESET}\n" "${SCRIPT_VERSION}"
    printf "${BOLD}${CYAN}============================================================${RESET}\n"
    printf " 当前状态: ${GREEN}%-8s${RESET}    当前端口: %s\n" "${state}" "${port}"
    echo "------------------------------------------------------------"
    echo " 1. 安装 SSR                 16. 查看 BBR 状态"
    echo " 2. 卸载 SSR                 17. 防火墙放行当前端口"
    echo " 3. 启动 SSR                 18. 生成 SSR 链接"
    echo " 4. 停止 SSR                 19. 生成 SSR 二维码"
    echo " 5. 重启 SSR                 20. 更新 SSR + 管理脚本"
    echo " 6. 查看运行状态             21. 重新编译安装（保留配置）"
    echo " 7. 查看连接信息             22. 系统环境检测"
    echo " 8. 修改端口                 23. 查看监听端口"
    echo " 9. 修改密码                 24. 查看服务器公网 IP"
    echo "10. 修改加密方式             25. 备份配置"
    echo "11. 修改协议                 26. 恢复配置"
    echo "12. 修改混淆                 27. 一键网络优化"
    echo "13. 开启/关闭 UDP            28. 查看完整配置"
    echo "14. 查看实时日志             29. 重置 SSR 配置"
    echo "15. 开启 BBR                  0. 退出"
    echo "------------------------------------------------------------"
    echo " 安装后可直接输入命令：ssr"
    echo "============================================================"
}

run_menu() {
    need_root
    check_os || exit 1
    install_manager_command

    while true; do
        show_menu
        local choice
        read -r -p "请输入数字 [0-29]: " choice || choice="0"
        echo
        case "${choice}" in
            1) install_ssr; press_enter ;;
            2) uninstall_ssr; press_enter ;;
            3) start_ssr; press_enter ;;
            4) stop_ssr; press_enter ;;
            5) restart_ssr; press_enter ;;
            6) status_ssr; press_enter ;;
            7) show_info; press_enter ;;
            8) change_port; press_enter ;;
            9) change_password; press_enter ;;
            10) change_method; press_enter ;;
            11) change_protocol; press_enter ;;
            12) change_obfs; press_enter ;;
            13) toggle_udp; press_enter ;;
            14) show_logs ;;
            15) enable_bbr; press_enter ;;
            16) show_bbr; press_enter ;;
            17) firewall_current_port; press_enter ;;
            18) generate_ssr_link; press_enter ;;
            19) show_qrcode; press_enter ;;
            20) update_ssr; press_enter ;;
            21) reinstall_binary; press_enter ;;
            22) environment_check; press_enter ;;
            23) show_listening_port; press_enter ;;
            24) show_public_ip; press_enter ;;
            25) backup_config; press_enter ;;
            26) restore_config; press_enter ;;
            27) network_tuning; press_enter ;;
            28) show_full_config; press_enter ;;
            29) reset_config; press_enter ;;
            0) echo "已退出。"; exit 0 ;;
            *) warn "无效选项：${choice}"; sleep 1 ;;
        esac
    done
}

# Optional non-interactive shortcuts for automation / troubleshooting.
case "${1:-menu}" in
    menu) run_menu ;;
    status) need_root; status_ssr ;;
    start) need_root; start_ssr ;;
    stop) need_root; stop_ssr ;;
    restart) need_root; restart_ssr ;;
    info) need_root; show_info ;;
    link) need_root; generate_ssr_link ;;
    logs) need_root; show_logs ;;
    env) need_root; environment_check ;;
    --version|-v) echo "SSR V2 Manager ${SCRIPT_VERSION}" ;;
    --help|-h)
        cat <<EOF_HELP
SSR V2 Manager ${SCRIPT_VERSION}

用法：
  sudo bash $0             进入数字管理菜单
  sudo bash $0 status      查看服务状态
  sudo bash $0 info        查看连接信息
  sudo bash $0 restart     重启 SSR
  sudo bash $0 link        生成 SSR 链接
  sudo bash $0 logs        查看实时日志
  sudo bash $0 env         系统环境检测

首次运行后会安装管理命令：
  ssr
EOF_HELP
        ;;
    *) err "未知参数：$1"; exit 1 ;;
esac
