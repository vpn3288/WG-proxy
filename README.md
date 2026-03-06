🚀 傻瓜式一键部署流程
请按顺序在对应的服务器上执行以下命令。

第一步：中转机（Relay）—— 建立加密隧道中心
在中转机上运行，它会自动配置 WireGuard 服务端，并准备好给落地机使用的配置文件。

Bash
wget -O zhongzhuan.sh https://raw.githubusercontent.com/vpn3288/WG-proxy/refs/heads/main/zhongzhuan.sh && bash zhongzhuan.sh
傻瓜说明：运行后按提示输入落地机名称，脚本会生成一串配置参数（私钥、内网IP等）。请复制保存，下一步要用。

第二步：落地机（Landing）—— 打通隧道与环境优化
在落地机上运行，它会自动处理甲骨文云等特殊防火墙，并建立与中转机的连接。

Bash
wget -O luodi.sh https://raw.githubusercontent.com/vpn3288/WG-proxy/refs/heads/main/luodi.sh && bash luodi.sh
傻瓜说明：填入第一步获取的中转机 IP 和密钥。看到 ping 10.0.0.1 成功即表示隧道打通。

注意：此时你可以自由安装 mack-a、yongge、fscarmen、3X-UI 等任何你喜欢的代理脚本。

第三步：落地机（Landing）—— 一键自动对接与生成链接
这是最关键的一步。它会调用 Python 引擎自动扫描你安装的代理节点（无论是 Reality、Hysteria2 还是其他），并自动 SSH 到中转机设置防火墙。

Bash
wget -O duijie.sh https://raw.githubusercontent.com/vpn3288/WG-proxy/refs/heads/main/duijie.sh && bash duijie.sh
傻瓜说明：

脚本会列出检测到的所有代理端口，你输入数字选择即可。

输入中转机的 SSH 密码。

结果：脚本会自动修改中转机的 iptables（通过调用远程 firewall.sh），并直接在屏幕上打印出修改好中转 IP 的全新代理链接。

🛡️ 方案深度解析：为什么它是“最好用”的？
1. 精准识别（保持几百行逻辑的精髓）
duijie.sh 内部集成的 Python 扫描逻辑，不再是简单的 grep，而是：

深度分析 JSON/SQLite：它可以区分 127.0.0.1 监听和公网监听，自动跳过不需要中转的内部端口。

多脚本适配：无论你用的是 mack-a 的 Xray 还是 yongge 的 Sing-box，它都能定位到 Reality 的 ShortId 和 PublicKey，确保生成的独立节点链接直接可用。

2. “游戏级”隐私与安全（SNAT 强制回程）
这是你要求的“网页无法识别代理”的核心。

防火墙逻辑：在 firewall.sh 中，我们不仅做了 DNAT（进入流量），更重要的是做了 SNAT --to-source 10.0.0.1。

效果：落地机接收到的请求，来源 IP 全部显示为隧道的内网地址。这样落地机的系统路由会强制将回程数据丢回隧道。这避免了“侧漏”风险，让你的流量特征完全符合正常的内网转发逻辑，有效对抗反代理检测。

3. 极致稳定与独立
独立节点：通过这套脚本生成的节点是完全独立的。即使你以后卸载了落地机上的某个面板，只要配置文件还在，中转依然有效。

免维护：WireGuard 运行在内核态，配合 systemd 的自愈机制和 PersistentKeepalive 保活。只要服务器不宕机，隧道永远在线。

💡 提示
安全建议：建议在中转机和落地机之间使用非标准 SSH 端口，并在 duijie.sh 中正确输入。

协议推荐：为了游戏稳定，推荐使用 Hysteria-2 或 Vless-reality-vision，这套脚本对这两个协议的端口跳跃和流控有专项逻辑优化。
