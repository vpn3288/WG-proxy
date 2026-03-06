#!/bin/bash
# ============================================================
# wg_port.sh — 端口转发精控逻辑 (v5.5)
# ============================================================
set -uo pipefail
G="\033[32m"; R="\033[31m"; W="\033[0m"

[[ $EUID -ne 0 ]] && exit 1

add_forward() {
    local l_ip=$1; local port=$2
    # 1. 外部流量映射到隧道内部
    iptables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "${l_ip}:${port}"
    iptables -t nat -A PREROUTING -p udp --dport "$port" -j DNAT --to-destination "${l_ip}:${port}"
    # 2. 核心：修改源IP为10.0.0.1，强制落地机通过隧道回程
    iptables -t nat -A POSTROUTING -d "${l_ip}" -p tcp --dport "$port" -j SNAT --to-source 10.0.0.1
    iptables -t nat -A POSTROUTING -d "${l_ip}" -p udp --dport "$port" -j SNAT --to-source 10.0.0.1
    iptables -A FORWARD -d "${l_ip}" -p tcp --dport "$port" -j ACCEPT
    iptables -A FORWARD -d "${l_ip}" -p udp --dport "$port" -j ACCEPT
    iptables-save > /etc/iptables/rules.v4
}

case "${1:-}" in
    --add) add_forward "$2" "$3" ;;
    --list) iptables -t nat -L PREROUTING -n --line-numbers ;;
    *) echo "用法: bash wg_port.sh --add [落地机IP] [端口]" ;;
esac
