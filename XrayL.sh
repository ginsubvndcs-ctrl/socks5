#!/usr/bin/env bash
# 一键搭建 SOCKS5 代理 (基于 XrayL, 非交互式, 账号密码端口写死)
# 参考: https://raw.githubusercontent.com/bulianglin/demo/main/xrayL.sh
# 用法: bash setup_xrayL_socks5.sh
set -e

# ====== 固定配置 ======
PORT="10010"
SOCKS_USERNAME="aaa"
SOCKS_PASSWORD="bbb"
# =======================

IP_ADDRESSES=($(hostname -I))

install_xray() {
	echo "安装 Xray..."
	if command -v apt-get >/dev/null 2>&1; then
		apt-get update -y >/dev/null 2>&1
		apt-get install -y unzip curl >/dev/null 2>&1
	elif command -v yum >/dev/null 2>&1; then
		yum install -y unzip curl >/dev/null 2>&1
	fi

	cd /tmp
	curl -sLO https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
	unzip -o Xray-linux-64.zip xray >/dev/null
	mv -f xray /usr/local/bin/xrayL
	chmod +x /usr/local/bin/xrayL

	cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.toml
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload
	systemctl enable xrayL.service >/dev/null 2>&1
	echo "Xray 安装完成."
}

config_xray() {
	mkdir -p /etc/xrayL
	config_content=""

	for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
		config_content+="[[inbounds]]\n"
		config_content+="port = $((PORT + i))\n"
		config_content+="protocol = \"socks\"\n"
		config_content+="tag = \"tag_$((i + 1))\"\n"
		config_content+="[inbounds.settings]\n"
		config_content+="auth = \"password\"\n"
		config_content+="udp = true\n"
		config_content+="ip = \"${IP_ADDRESSES[i]}\"\n"
		config_content+="[[inbounds.settings.accounts]]\n"
		config_content+="user = \"$SOCKS_USERNAME\"\n"
		config_content+="pass = \"$SOCKS_PASSWORD\"\n"
		config_content+="[[outbounds]]\n"
		config_content+="sendThrough = \"${IP_ADDRESSES[i]}\"\n"
		config_content+="protocol = \"freedom\"\n"
		config_content+="tag = \"tag_$((i + 1))\"\n\n"
		config_content+="[[routing.rules]]\n"
		config_content+="type = \"field\"\n"
		config_content+="inboundTag = \"tag_$((i + 1))\"\n"
		config_content+="outboundTag = \"tag_$((i + 1))\"\n\n\n"
	done

	echo -e "$config_content" >/etc/xrayL/config.toml
	systemctl restart xrayL.service
}

install_xray
config_xray

echo ""
echo "======== SOCKS5 (XrayL) 搭建完成 ========"
echo "地址:   ${IP_ADDRESSES[0]}"
echo "端口:   $PORT"
echo "账号:   $SOCKS_USERNAME"
echo "密码:   $SOCKS_PASSWORD"
echo "=========================================="
echo "客户端连接示例: socks5://$SOCKS_USERNAME:$SOCKS_PASSWORD@${IP_ADDRESSES[0]}:$PORT"
