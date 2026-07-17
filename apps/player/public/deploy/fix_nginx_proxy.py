#!/usr/bin/env python3
"""修复 nginx proxy_pass 配置"""
import sys
try:
    import paramiko
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "paramiko"])
    import paramiko

HOST = "124.220.234.157"
USER = "ubuntu"
PASS = "Akira0036"

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=15)
sftp = ssh.open_sftp()
print("✅ SSH 连接\n")

def run(cmd):
    print(f"$ {cmd}")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=30)
    out = stdout.read().decode("utf-8", errors="replace").strip()
    if out: print(out)
    print()

print("="*60)
print("1. 修正 nginx 配置（去掉 proxy_pass 末尾斜杠）")
print("="*60)

nginx_conf = """server {
    listen 80;
    server_name _;
    root /opt/dgbook/player;
    index index.html;
    gzip on;
    gzip_types text/plain application/json application/javascript text/css;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
        chunked_transfer_encoding on;
    }
}"""

with sftp.open("/tmp/dgbook_fixed.conf", "w") as f:
    f.write(nginx_conf)

run("sudo cp /tmp/dgbook_fixed.conf /etc/nginx/sites-available/dgbook")
run("sudo nginx -t")
run("sudo systemctl reload nginx")

print("="*60)
print("2. 验证修复")
print("="*60)
run("curl -s http://127.0.0.1/api/health | head -c 100")
run("curl -s http://127.0.0.1/api/courses/stm32-course/manifest | head -c 200")

sftp.close()
ssh.close()
print("\n✅ nginx 配置已修复！")
