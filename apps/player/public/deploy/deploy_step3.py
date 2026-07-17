#!/usr/bin/env python3
"""DGBook 部署 - 第三步：修复 BFF 启动错误"""
import sys, time

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
ssh.connect(HOST, username=USER, password=PASS, timeout=30)
sftp = ssh.open_sftp()
print("✅ SSH 连接成功")

def run(cmd, timeout=60, check=True):
    print(f"$ {cmd[:90]}")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    rc = stdout.channel.recv_exit_status()
    if out: print(f"  {out[-400:]}")
    if err and rc != 0: print(f"  ERR: {err[-300:]}")
    if check and rc != 0: raise RuntimeError(f"命令失败(rc={rc})")
    return rc

# 1. 查看当前错误日志
print("\n[1] 查看 BFF 错误日志")
run("sudo journalctl -u dgbook-bff -n 20 --no-pager", check=False)

# 2. 创建必要目录和配置
print("\n[2] 修复配置")
run("mkdir -p /opt/dgbook/materials")

# 写入修正的 .env（加入 DG_MATERIALS_ROOT）
env_content = (
    "DASHSCOPE_API_KEY=your_dashscope_api_key\n"
    "DASHSCOPE_MODEL=qwen-plus\n"
    "DASHSCOPE_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1\n"
    "DG_MATERIALS_ROOT=/opt/dgbook/materials\n"
    "CORS_ORIGINS=*\n"
)
with sftp.open("/opt/dgbook/bff/.env", "w") as f:
    f.write(env_content)
print("✅ .env 更新（加入 DG_MATERIALS_ROOT）")

# 3. 测试导入
print("\n[3] 测试 BFF 启动")
run("cd /opt/dgbook/bff && venv/bin/python -c 'from app.main import app; print(\"✅ 导入成功\")'", check=False)

# 4. 重启服务
print("\n[4] 重启 BFF 服务")
run("sudo systemctl restart dgbook-bff")
time.sleep(5)
run("sudo systemctl status dgbook-bff --no-pager | head -20", check=False)

# 5. 验证
print("\n[5] 健康检查")
time.sleep(2)
run("curl -s http://127.0.0.1:8001/health || echo 'BFF 还未就绪'", check=False)
run("curl -s -o /dev/null -w 'nginx /api/health: %{http_code}\\n' http://127.0.0.1/api/health", check=False)
run("curl -s http://127.0.0.1/ | grep -o '<title>[^<]*</title>'", check=False)

sftp.close()
ssh.close()
print("\n✅ BFF 修复完成")
print("访问: http://124.220.234.157/")
print("API:  http://124.220.234.157/api/health")
