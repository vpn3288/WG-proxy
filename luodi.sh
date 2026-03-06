#!/bin/bash
# ============================================================
# wg_luodi.sh — 落地机 WireGuard 安全连接
# ============================================================
set -uo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'

# 1. 甲骨文云特殊适配
if [[ -d /etc/oracle-cloud-agent ]]; then
    iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -F
    iptables-save > /etc/iptables/rules.v4
    echo "检测到甲骨文云，已开放默认防火墙规则。"
fi

apt-get update -qq && apt-get install -y -qq wireguard openresolv curl

read -p "中转机 IP: " R_IP
read -p "中转机 WG 公钥: " R_PUB
read -p "分配给本机的私钥: " M_PRIV
read -p "分配给本机的 WG IP (10.0.0.x): " M_IP

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $M_PRIV
Address = $M_IP/32
DNS = 8.8.8.8
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
[Peer]
PublicKey = $R_PUB
Endpoint = $R_IP:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
EOF

systemctl enable --now wg-quick@wg0
systemctl restart wg-quick@wg0
sleep 2
ping -c 2 10.0.0.1 && echo -e "${GREEN}隧道连通成功！${NC}" || echo -e "${RED}失败，请检查防火墙${NC}"
