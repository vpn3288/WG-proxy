#!/bin/bash
# ============================================================
# wg_duijie.sh — 跨平台代理后端自动扫描与对接 (完美版)
# ============================================================
set -uo pipefail
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# 1. 增强型 Python 扫描引擎 (精准识别各路脚本路径)
SCANNER_PY=$(cat << 'EOF'
import json, os, sqlite3

def scan():
    results = []
    # 路径 1: mack-a (Xray/Singbox)
    paths = ["/etc/v2ray-agent/xray/conf/", "/etc/v2ray-agent/singbox/conf/"]
    for p in paths:
        if os.path.exists(p):
            for f in os.listdir(p):
                if f.endswith(".json"):
                    with open(p+f, 'r') as j:
                        data = json.load(j)
                        for ib in data.get('inbounds', []):
                            if ib.get('listen') != "127.0.0.1":
                                results.append({"port": ib['port'], "tag": ib.get('tag', 'mack-a')})

    # 路径 2: yonggekkk / fscarmen
    box_paths = ["/root/sing-box/config.json", "/etc/sing-box/config.json"]
    for p in box_paths:
        if os.path.exists(p):
            with open(p, 'r') as j:
                data = json.load(j)
                for ib in data.get('inbounds', []):
                    results.append({"port": ib['port'], "tag": "yg/fscarmen"})

    # 路径 3: X-UI / 3X-UI (SQLite 数据库)
    if os.path.exists("/etc/x-ui/x-ui.db"):
        conn = sqlite3.connect("/etc/x-ui/x-ui.db")
        cur = conn.cursor()
        for row in cur.execute("SELECT port, remark FROM inbounds WHERE enable=1"):
            results.append({"port": row[0], "tag": f"X-UI({row[1]})"})
        conn.close()
    
    return results

data = scan()
print("\n".join([f"{i+1}) 端口: {d['port']} [{d['tag']}]" for i, d in enumerate(data)]))
print("PORTS:" + " ".join([str(d['port']) for d in data]))
EOF
)

echo -e "${CYAN}正在扫描本地代理后端...${NC}"
SCAN_OUTPUT=$(python3 -c "$SCANNER_PY")
echo -e "$SCAN_OUTPUT" | grep -v "PORTS:"

read -p "请输入要对接的序号 (空格分隔): " CHOICE_IDS
PORTS_STR=$(echo "$SCAN_OUTPUT" | grep "PORTS:" | sed 's/PORTS://')
SELECTED_PORTS=()
for id in $CHOICE_IDS; do
    SELECTED_PORTS+=($(echo "$PORTS_STR" | cut -d' ' -f$id))
done

# 2. SSH 联动逻辑
read -p "中转机公网 IP: " RELAY_IP
read -p "中转机 SSH 端口 [22]: " SSH_P; SSH_P=${SSH_P:-22}
read -p "使用密码(p)还是密钥(k)登录中转机? [p]: " AUTH_TYPE; AUTH_TYPE=${AUTH_TYPE:-p}

# 获取本机 WG 内部 IP
MY_WG_IP=$(ip addr show wg0 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

CMD=""
for p in "${SELECTED_PORTS[@]}"; do
    CMD+="bash /etc/wireguard/wg_port.sh --add $MY_WG_IP $p; "
done

if [[ "$AUTH_TYPE" == "p" ]]; then
    apt-get install -y sshpass &>/dev/null
    read -rs -p "输入中转机密码: " SSH_PASS; echo ""
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -p "$SSH_P" root@"$RELAY_IP" "$CMD"
else
    ssh -o StrictHostKeyChecking=no -p "$SSH_P" root@"$RELAY_IP" "$CMD"
fi

echo -e "${GREEN}对接成功！${NC}"
echo -e "${YELLOW}请将你原有客户端节点中的 IP 地址替换为中转机 IP: $RELAY_IP 即可实现独立中转。${NC}"
