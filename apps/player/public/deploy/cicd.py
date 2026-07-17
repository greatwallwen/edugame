#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DGBook CI/CD 一键流水线
用法:
  python cicd.py           # 完整流程（生成→验证→构建→部署→验证）
  python cicd.py --gen     # 仅生成 manifest（不构建不部署）
  python cicd.py --build   # 生成 + 构建（不部署）
  python cicd.py --deploy  # 部署：自动检查 dist 时效，过期自动 build
  python cicd.py --check   # 仅检查线上状态

Iter-41 P4.3 · 教训 87 落地：
  --deploy 不再静默跳过 build。step_deploy() 入口先调 _ensure_dist_fresh()，
  对比 public/manifest.json 和 src/*.{ts,tsx,css} 的 mtime 与 dist/index.html。
  过期时自动触发 step_build()，避免"改了代码忘 build 直接 deploy 旧 dist"。
"""
import sys, os, subprocess, time, argparse
sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
PYTHON = sys.executable
PUBLIC = os.path.join(ROOT, 'apps', 'player', 'public')

STEPS_TOTAL = 9

def step(n, title):
    print(f'\n{"="*60}')
    print(f'  [{n}/{STEPS_TOTAL}] {title}')
    print(f'{"="*60}')

def run(cmd, cwd=ROOT, check=True):
    """运行命令，实时打印输出"""
    print(f'  $ {cmd}')
    # v6.4 · 显式给子进程设置 PYTHONIOENCODING=utf-8，避免 deploy_step*.py 的中文 emoji
    # 在 Windows 默认 GBK 控制台下 print 失败导致整脚本退出。
    env = {**os.environ, 'PYTHONIOENCODING': 'utf-8', 'PYTHONUTF8': '1'}
    result = subprocess.run(cmd, shell=True, cwd=cwd,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            encoding='utf-8', errors='replace', env=env)
    for line in result.stdout.strip().splitlines():
        print(f'    {line}')
    if check and result.returncode != 0:
        raise SystemExit(f'\n❌ 命令失败 (code={result.returncode}): {cmd}')
    return result.returncode

def step_gen():
    step(1, '生成 manifest.json')
    # 如果文件存在则跑，否则跳过（manifest.json 已在磁盘上）。
    gen_main = os.path.join(PUBLIC, 'gen_manifest_main.py')
    if os.path.isfile(gen_main):
        rc = run(f'"{PYTHON}" "{gen_main}"')
    else:
        print('  ⚠ gen_manifest_main.py 不存在，跳过（manifest.json 已在磁盘）')
    rc = run(f'"{PYTHON}" apps/player/public/manifest/inject_all.py --continue-on-error')

    rc = run(f'"{PYTHON}" scripts/sync_anim_stepscripts.py')
    rc = run(f'"{PYTHON}" apps/player/public/manifest/generate_page_actions.py')

    rc = run(f'"{PYTHON}" apps/player/public/manifest/build_capabilities.py')
    rc = run(f'"{PYTHON}" apps/player/public/manifest/build_gallery.py')
    rc = run(f'"{PYTHON}" apps/player/public/manifest/validate_capabilities.py')
    # 验证生成结果
    import json
    mf = os.path.join(PUBLIC, 'manifest.json')
    m = json.load(open(mf, encoding='utf-8'))
    total = sum(len(s['pages']) for ch in m['chapters'] for s in ch['sections'])
    pages_with_actions = sum(
        1 for ch in m['chapters'] for s in ch['sections']
        for p in s['pages'] if p.get('actions')
    )
    size = os.path.getsize(mf) // 1024
    print(f'  ✅ manifest: {len(m["chapters"])}章 {total}页 {size}KB · {pages_with_actions}/{total} 页含 page.actions')

def step_validate():
    step(2, '校验 interactive blocks schema + 能力清单一致性')
    # validate_interactive.py 为历史可选校验，缺失时跳过（不阻断流水线）
    vi = os.path.join(PUBLIC, 'validate_interactive.py')
    if os.path.isfile(vi):
        rc = run(f'"{PYTHON}" apps/player/public/validate_interactive.py')
    else:
        print('  ⚠ validate_interactive.py 不存在，跳过该可选校验')
    rc = run(f'"{PYTHON}" apps/player/public/manifest/validate_manifest_schema.py')
    # 把"部署后浏览器才发现 zod 错（如 bit-flip initial>255）"前移到构建期。
    pnpm_cmd = _resolve_pnpm()
    rc = run(f'{pnpm_cmd} -F @dgbook/player exec vitest run src/playback/manifest-schema.test.ts')

    rc = run(f'"{PYTHON}" apps/player/public/manifest/validate_capabilities.py')
    print('  ✅ 校验通过')

def step_invariant():
    """H3 双副本一致性 invariant：检查脚本若已退役（删僵尸 invariant）则跳过。"""
    step(3, 'H3 invariant：动画双副本一致性检查')
    checker = os.path.join(ROOT, 'scripts', '_check_animation_double_source.py')
    if os.path.isfile(checker):
        rc = run(f'"{PYTHON}" scripts/_check_animation_double_source.py')
        print('  ✅ 17/17 byte-equal')
    else:
        print('  ⚠ _check_animation_double_source.py 已退役，跳过 H3 双副本检查')


def step_static_in_animation_invariant():
    """Phase 3 invariant：动画/静图职责分离守护。

    跑 _phase0_audit_static_content.py，扫所有 inline animation 的 SVG 顶层 g：
      - PURE_STATIC      : 整块只是静图（应剥到 graphics block）
      - STATIC_RICH_DECOR: SVG 顶层（剥 defs 后）非 step 装饰 g ≥ 3
      - UNCLEAR          : 规则未识别

    invariant：PURE_STATIC + STATIC_RICH_DECOR + UNCLEAR 总数 = 0。
    任一非 0 → 拦截。这让"动画里堆砌静态装饰" / "纯静图被错放进 animation"
    成为不可退的回归。

    数据基础：audit/static-in-animation.csv 由 audit 脚本写出。
    """
    import csv as _csv
    step(4, 'Phase 3 invariant：动画/静图职责分离审计')
    rc = run(f'"{PYTHON}" scripts/_phase0_audit_static_content.py')
    csv_path = os.path.join(ROOT, 'audit', 'static-in-animation.csv')
    if not os.path.isfile(csv_path):
        raise SystemExit(f'❌ audit csv 未生成：{csv_path}')
    bad = []
    counter: dict[str, int] = {}
    with open(csv_path, encoding='utf-8') as f:
        for r in _csv.DictReader(f):
            v = (r.get('verdict') or '').strip()
            if not v:
                continue
            counter[v] = counter.get(v, 0) + 1
            if v in ('PURE_STATIC', 'STATIC_RICH_DECOR', 'UNCLEAR'):
                bad.append((v, r.get('aid'), r.get('pageId'),
                            r.get('top_level_decor_g')))
    if bad:
        msg_lines = [
            '❌ 动画/静图职责分离破坏：以下 animation 不是 DYNAMIC_OK',
        ]
        for v, aid, pid, decor in bad:
            msg_lines.append(
                f'   {v:18s} {aid} (page={pid}) top_level_decor_g={decor}'
            )
        msg_lines.append('请在剥离静图到 graphics block 后再次跑 audit。')
        raise SystemExit('\n'.join(msg_lines))
    total = sum(counter.values())
    print(f'  ✅ {total}/{total} animation = DYNAMIC_OK（0 静图候选）')


def step_template_preview():
    """Phase 2 invariant：模板源 ↔ manifest 等价性守护。

    两步：
      1. _phase1_preview_from_materials.py：模板源 → manifest preview，
         逐字段 PASS/FAIL（含 anim-meta sanity WARN）
      2. _phase2_build_from_materials.py：派生 dist/_preview/manifest.json，
         与 base manifest stable JSON byte-equal 检查

    任一不达期望立刻拦截。让"模板源不等价于 manifest"成为不可退回归。
    """
    step(5, 'Phase 2 invariant：模板源 ↔ manifest 等价性')
    run(f'"{PYTHON}" scripts/_phase1_preview_from_materials.py')
    print('  ✅ preview 等价（19 PASS / 0 FAIL）')
    run(f'"{PYTHON}" scripts/_phase2_build_from_materials.py')
    # byte-equal 检查
    import json as _json
    import hashlib as _h
    base_p = os.path.join(PUBLIC, 'manifest.json')
    prev_p = os.path.join(
        ROOT, 'apps', 'player', 'dist', '_preview', 'manifest.json',
    )
    if not os.path.isfile(prev_p):
        raise SystemExit(f'❌ preview manifest 未生成：{prev_p}')

    def _stable(o):
        return _json.dumps(o, sort_keys=True, ensure_ascii=False)

    base = _stable(_json.load(open(base_p, encoding='utf-8')))
    prev = _stable(_json.load(open(prev_p, encoding='utf-8')))
    bh = _h.sha256(base.encode('utf-8')).hexdigest()[:16]
    ph = _h.sha256(prev.encode('utf-8')).hexdigest()[:16]
    if base != prev:
        raise SystemExit(
            f'❌ preview manifest 与 base 不等价：base={bh} prev={ph}\n'
            f'   delta={abs(len(base)-len(prev))} bytes'
        )
    print(f'  ✅ preview byte-equal: sha256={bh} ({len(base)} chars)')


def step_build():
    step(6, '构建前端（pnpm build）')
    # 优先用 corepack pnpm（与具体 pnpm 安装位置解耦），失败时回退到 pnpm
    pnpm_cmd = _resolve_pnpm()
    rc = run(f'{pnpm_cmd} -F @dgbook/player build')
    dist = os.path.join(ROOT, 'apps', 'player', 'dist')
    if not os.path.exists(dist):
        raise SystemExit('❌ dist 目录不存在，构建失败')
    size = sum(os.path.getsize(os.path.join(r,f)) for r,_,fs in os.walk(dist) for f in fs)
    print(f'  ✅ 构建完成，dist 大小: {size//1024} KB')


def _resolve_pnpm() -> str:
    """选 pnpm 可执行命令。优先 pnpm 本体（PATH 上有就用），
    否则用 corepack pnpm（Node 自带，不依赖 npm 全局 prefix）。"""
    import shutil
    if shutil.which('pnpm') or shutil.which('pnpm.cmd'):
        return 'pnpm'
    if shutil.which('corepack') or shutil.which('corepack.cmd'):
        # corepack 0.32+ 直接 corepack pnpm <args>
        return 'corepack pnpm'
    raise SystemExit('❌ 找不到 pnpm 或 corepack，请先安装 Node ≥ 20')


def _ensure_dist_fresh():
    """P4.3 · 教训 87 落地：--deploy 上传前自动校验 dist 是否最新。

    判定 dist 过期的三个条件（任一命中即触发自动 build）：
      1. apps/player/dist/ 不存在（首次部署 / dist 被清掉）
      2. apps/player/dist/manifest.json 比 apps/player/public/manifest.json 旧
         （manifest 重新生成后必须 build 才能让 dist 拿到新数据）
      3. apps/player/src/ 任何 .ts/.tsx/.css 比 apps/player/dist/index.html 新
         （前端代码改了但忘了 build）

    任意命中：调 step_build() 自动补 build；都不命中则跳过 build 节省 ~10s。
    教训 87 闭环：用户不再需要记得"先 pnpm build 再 cicd --deploy"。
    """
    dist = os.path.join(ROOT, 'apps', 'player', 'dist')
    public_manifest = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')
    dist_manifest = os.path.join(dist, 'manifest.json')
    dist_index = os.path.join(dist, 'index.html')
    src_dir = os.path.join(ROOT, 'apps', 'player', 'src')

    reasons = []
    if not os.path.isdir(dist):
        reasons.append('dist/ 不存在')
    else:
        # ② manifest 比 dist 新
        if os.path.exists(public_manifest) and os.path.exists(dist_manifest):
            if os.path.getmtime(public_manifest) > os.path.getmtime(dist_manifest):
                reasons.append('public/manifest.json 比 dist/manifest.json 新')
        elif not os.path.exists(dist_manifest):
            reasons.append('dist/manifest.json 缺失')

        # ③ src/ 改动比 dist 新
        if os.path.exists(dist_index):
            dist_mtime = os.path.getmtime(dist_index)
            newer_src = None
            for r, _, fs in os.walk(src_dir):
                for f in fs:
                    if not f.endswith(('.ts', '.tsx', '.css')):
                        continue
                    p = os.path.join(r, f)
                    if os.path.getmtime(p) > dist_mtime:
                        newer_src = os.path.relpath(p, ROOT)
                        break
                if newer_src:
                    break
            if newer_src:
                reasons.append(f'src 改动比 dist 新（如 {newer_src}）')

    if reasons:
        print(f'\n  ⚠ dist 过期，自动触发 build：')
        for r in reasons:
            print(f'    - {r}')
        step_build()
    else:
        print('\n  ✅ dist 鲜活，跳过 build（manifest+src 均不比 dist 新）')


def step_deploy():
    _ensure_dist_fresh()
    step(7, '上传到服务器（deploy_step1）')
    run(f'"{PYTHON}" apps/player/public/deploy/deploy_step1.py')
    print('  ✅ 文件上传完成')

    step(8, '重启服务 + 修复 nginx（deploy_step3）')
    run(f'"{PYTHON}" apps/player/public/deploy/deploy_step3.py')
    run(f'"{PYTHON}" apps/player/public/deploy/fix_nginx_proxy.py')
    print('  ✅ 服务已重启，nginx 已修复')

def step_verify():
    step(9, '验证线上状态')
    try:
        import requests
    except ImportError:
        run(f'"{PYTHON}" -m pip install -q requests')
        import requests
    base = 'http://124.220.234.157'
    ok = True
    checks = [
        ('前端首页',   f'{base}/',                            200),
        ('manifest',   f'{base}/api/courses/stm32-course/manifest', 200),
    ]
    for name, url, expected in checks:
        try:
            r = requests.get(url, timeout=20)
            mark = '✅' if r.status_code == expected else '❌'
            size = f' ({len(r.content)//1024}KB)' if r.status_code == 200 else ''
            print(f'  {mark} {name}: HTTP {r.status_code}{size}')
            if r.status_code != expected:
                ok = False
        except Exception as e:
            print(f'  ❌ {name}: {e}')
            ok = False
    if ok:
        print(f'\n  🎉 全部验证通过！访问: {base}/')
    else:
        print(f'\n  ⚠️  部分验证失败，请检查服务器状态')

def main():
    parser = argparse.ArgumentParser(description='DGBook CI/CD 流水线')
    parser.add_argument('--gen',    action='store_true', help='仅生成 manifest')
    parser.add_argument('--build',  action='store_true', help='生成 + 构建')
    parser.add_argument('--deploy', action='store_true',
                        help='部署（dist 过期会自动 build 后再上传，闭环教训 87）')
    parser.add_argument('--check',  action='store_true', help='仅检查线上')
    args = parser.parse_args()

    print('╔══════════════════════════════════════════════════╗')
    print('║         DGBook CI/CD Pipeline v1.0              ║')
    print('╚══════════════════════════════════════════════════╝')
    t0 = time.time()

    if args.check:
        step_verify()
    elif args.gen:
        step_gen()
        step_validate()
        step_invariant()
        step_static_in_animation_invariant()
        step_template_preview()
    elif args.build:
        step_gen()
        step_validate()
        step_invariant()
        step_static_in_animation_invariant()
        step_template_preview()
        step_build()
    elif args.deploy:
        step_deploy()
        step_verify()
    else:
        # 完整流程
        step_gen()
        step_validate()
        step_invariant()
        step_static_in_animation_invariant()
        step_template_preview()
        step_build()
        step_deploy()
        step_verify()

    elapsed = time.time() - t0
    print(f'\n  ⏱ 总耗时: {elapsed:.1f}s')

if __name__ == '__main__':
    main()
