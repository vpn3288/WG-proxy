#!/bin/bash
# ============================================================
# wg_zhongzhuan.sh — CN2GIA 中转机核心逻辑
# ============================================================
set -uo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
WORK_DIR="/etc/wireguard"; SUMMARY="$WORK_DIR/relay-info.txt"
mkdir -p "$WORK_DIR/peers"

[[ $EUID -ne 0 ]] && echo "需root权限" && exit 1

# 1. 环境初始化 (BBR+必备组件)
info() { echo -e "${CYAN}[i] $1${NC}"; }
ok()   { echo -e "${GREEN}[✓] $1${NC}"; }

info "正在加固中转机系统环境..."
apt-get update -qq && apt-get install -y -qq wireguard iptables-persistent curl qrencode python3

# 开启内核转发与BBR
cat > /etc/sysctl.d/99-relay.conf <<EOF
net.ipv4.ip_forward=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p /etc/sysctl.d/99-relay.conf &>/dev/null

# 2. 获取网络元数据
WAN_IF=$(ip route show default | awk '/default/{print $5; exit}')
RELAY_IP=$(curl -s4 https://api.ipify.org || curl -s4 https://ifconfig.me)

# 3. 初始化或追加配置 (幂等逻辑)
if [[ ! -f "$WORK_DIR/wg0.conf" ]]; then
    info "初始化 WireGuard 服务端..."
    read -p "监听端口 [51820]: " WG_PORT; WG_PORT=${WG_PORT:-51820}
    PRIV=$(wg genkey); PUB=$(echo "$PRIV" | wg pubkey)
    cat > "$WORK_DIR/wg0.conf" <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = $WG_PORT
PrivateKey = $PRIV
# 核心转发逻辑：允许转发并开启 MASQUERADE
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $WAN_IF -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $WAN_IF -j MASQUERADE
EOF
    echo "RELAY_IP=$RELAY_IP" > "$SUMMARY"
    echo "RELAY_PUB=$PUB" >> "$SUMMARY"
    echo "RELAY_PORT=$WG_PORT" >> "$SUMMARY"
else
    source "$SUMMARY"
    info "检测到已有配置，准备追加落地机..."
fi

# 4. 生成落地机配置
read -p "输入该落地机名称 (如 us-home): " PEER_NAME
PEER_PRIV=$(wg genkey); PEER_PUB=$(echo "$PEER_PRIV" | wg pubkey)
# 自动计算下一个 IP
EXIST_COUNT=$(grep -c "\[Peer\]" "$WORK_DIR/wg0.conf" || echo 0)
PEER_IP="10.0.0.$((EXIST_COUNT + 2))"

cat >> "$WORK_DIR/wg0.conf" <<EOF
[Peer]
# Name: $PEER_NAME
PublicKey = $PEER_PUB
AllowedIPs = $PEER_IP/32
EOF

# 生成供落地机下载的独立配置
cat > "$WORK_DIR/peers/${PEER_NAME}.conf" <<EOF
[Interface]
PrivateKey = $PEER_PRIV
Address = $PEER_IP/32
DNS = 1.1.1.1
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
[Peer]
PublicKey = $RELAY_PUB
Endpoint = $RELAY_IP:$RELAY_PORT
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
EOF

systemctl restart wg-quick@wg0
ok "中转机配置完成！请在落地机使用以下参数："
echo -e "${YELLOW}落地机 WG IP: $PEER_IP | 私钥: $PEER_PRIV | 中转公钥: $RELAY_PUB${NC}"
