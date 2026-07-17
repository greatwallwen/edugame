#!/usr/bin/env python3
"""DGBook 分步部署 - 第一步：上传前端文件"""
import sys, tarfile, tempfile, os, pathlib

# 安装 paramiko
try:
    import paramiko
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "paramiko"])
    import paramiko

HOST = "124.220.234.157"
USER = "ubuntu"
PASS = "Akira0036"
ROOT = pathlib.Path(r"d:\cursor\DGBook")
DIST = ROOT / "apps/player/dist"
BFF  = ROOT / "apps/bff"

print(f"ROOT: {ROOT}")
print(f"DIST exists: {DIST.exists()}")

# 连接
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASS, timeout=30)
sftp = ssh.open_sftp()
print("✅ SSH 连接成功")

def run(cmd):
    print(f"$ {cmd}")
    _, stdout, stderr = ssh.exec_command(cmd, timeout=120)
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    rc = stdout.channel.recv_exit_status()
    if out: print(out)
    if err and rc != 0: print(f"ERR: {err[:200]}")
    return rc

# 1. 创建目录
run("sudo mkdir -p /opt/dgbook/player /opt/dgbook/bff && sudo chown -R ubuntu:ubuntu /opt/dgbook")

# 2. 打包上传前端
print("\n[前端] 打包 dist...")
tmp = tempfile.mktemp(suffix=".tar.gz")
with tarfile.open(tmp, "w:gz") as tar:
    tar.add(str(DIST), arcname="dist")
kb = os.path.getsize(tmp) // 1024
print(f"  大小: {kb} KB")
print("  上传中...", end="", flush=True)
sftp.put(tmp, "/tmp/player.tar.gz")
os.unlink(tmp)
print(" 完成")
run("cd /tmp && tar xzf player.tar.gz && rsync -a --delete dist/ /opt/dgbook/player/ && rm -rf dist player.tar.gz")
run("ls -lh /opt/dgbook/player/index.html /opt/dgbook/player/manifest.json")
print("✅ 前端部署完成")

# 3. 打包上传 BFF
print("\n[BFF] 打包源码...")
tmp2 = tempfile.mktemp(suffix=".tar.gz")
with tarfile.open(tmp2, "w:gz") as tar:
    tar.add(str(BFF / "app"), arcname="app")
    tar.add(str(BFF / "pyproject.toml"), arcname="pyproject.toml")
kb2 = os.path.getsize(tmp2) // 1024
print(f"  大小: {kb2} KB")
print("  上传中...", end="", flush=True)
sftp.put(tmp2, "/tmp/bff.tar.gz")
os.unlink(tmp2)
print(" 完成")
run("cd /opt/dgbook/bff && tar xzf /tmp/bff.tar.gz && rm /tmp/bff.tar.gz")
print("✅ BFF 源码部署完成")

# 4. 写 .env
env_content = (
    "DASHSCOPE_API_KEY=your_dashscope_api_key\n"
    "DASHSCOPE_MODEL=qwen-plus\n"
    "CORS_ORIGINS=*\n"
    "DG_MATERIALS_ROOT=/opt/dgbook/materials\n"
)
with sftp.open("/opt/dgbook/bff/.env", "w") as f:
    f.write(env_content)
print("✅ .env 写入完成")

# 5. 同步 BFF 读取的 manifest 副本（DG_MATERIALS_ROOT/<course>/generated/manifest.json）
# BFF 路由 apps/bff/app/routers/courses.py:get_manifest 读的是
# materials/<courseId>/generated/manifest.json，而不是前端 dist/manifest.json。
# 不同步会导致 /api/courses/stm32-course/manifest 返回旧版 manifest。
# 用 dist/manifest.json 作为唯一 source-of-truth（与前端 100% 一致）。
print("\n[manifest] 同步到 BFF materials 目录...")
LOCAL_MF = DIST / "manifest.json"
if LOCAL_MF.exists():
    REMOTE_MF_DIR = "/opt/dgbook/materials/stm32-course/generated"
    REMOTE_MF = f"{REMOTE_MF_DIR}/manifest.json"
    run(f"mkdir -p {REMOTE_MF_DIR}")
    sftp.put(str(LOCAL_MF), REMOTE_MF)
    sz = os.path.getsize(LOCAL_MF) // 1024
    print(f"  ✅ 已上传 {LOCAL_MF.name} -> {REMOTE_MF} ({sz} KB)")
    run(f"wc -c {REMOTE_MF}")
else:
    print(f"  ⚠️  本地缺失 {LOCAL_MF}，BFF 仍读旧版 manifest")

sftp.close()
ssh.close()
print("\n✅ 第一步：文件上传完成！")
print("请运行 deploy_step2.py 安装依赖并配置服务")
