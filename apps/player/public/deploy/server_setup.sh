#!/bin/bash
# DGBook 云端服务器初始化脚本 (Ubuntu)
# 用途: 安装nginx, Python, 配置systemd服务
set -e

echo "=== [1/6] 更新系统包 ==="
apt-get update -qq

echo "=== [2/6] 安装 nginx ==="
apt-get install -y nginx

echo "=== [3/6] 安装 Python3 pip ==="
apt-get install -y python3-pip python3-venv

echo "=== [4/6] 创建应用目录 ==="
mkdir -p /opt/dgbook/player
mkdir -p /opt/dgbook/bff

echo "=== [5/6] 配置 nginx ==="
cat > /etc/nginx/sites-available/dgbook << 'NGINX_CONF'
server {
    listen 80;
    server_name _;

    # 静态前端
    root /opt/dgbook/player;
    index index.html;

    # SPA 路由回退
    location / {
        try_files $uri $uri/ /index.html;
    }

    # BFF API 反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:8001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        # SSE 流式响应支持
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
        chunked_transfer_encoding on;
    }
}
NGINX_CONF

ln -sf /etc/nginx/sites-available/dgbook /etc/nginx/sites-enabled/dgbook
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "=== [6/6] 安装 BFF Python 依赖 ==="
cd /opt/dgbook/bff
python3 -m venv venv
source venv/bin/activate
pip install -q fastapi uvicorn[standard] httpx sse-starlette pydantic-settings

echo "=== 服务器初始化完成 ==="
